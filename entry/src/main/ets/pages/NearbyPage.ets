import { common } from '@kit.AbilityKit';
import { PlacesApi, ReminderApi } from '../api/Api';
import { FG } from '../common/Theme';
import { DisclaimerBar } from '../components/DisclaimerBar';
import { EmptyState } from '../components/EmptyState';
import { FgButton } from '../components/FgButton';
import { FgChip } from '../components/FgChip';
import { Icon } from '../components/Icon';
import { PageHeader } from '../components/PageHeader';
import { NearbyNavParam, NearbyPlace, PlaceCategory, WalkRoute } from '../models/Types';
import { todayText } from '../utils/Format';
import { GeoPoint, requestGeo, savedGeo } from '../utils/Geo';
import { showToast } from '../utils/Http';
import { EMPTY_PARAM, Nav } from '../utils/Nav';

interface NearbyRouteInfo {
  place: NearbyPlace;
  distanceMeters: number;
  durationSeconds: number;
}

/** 周边资源：定位后查询附近宠物医院/公园，支持步行路线与遛弯打卡回写 */
@Component
export struct NearbyPage {
  linkedReminderId: number = 0;
  linkedReminderTitle: string = '';
  linkedPetId: number = 0;
  initialCategory: PlaceCategory = 'medical';
  showBack: boolean = false;
  navParam: Object = EMPTY_PARAM;
  @State private geoStatus: string = 'locating';
  @State private geoMessage: string = '定位未成功';
  @State private accuracy: number = 0;
  @State private centerLat: number = 0;
  @State private centerLng: number = 0;
  @State private category: PlaceCategory = 'medical';
  @State private radius: number = 3000;
  @State private places: NearbyPlace[] = [];
  @State private placesStatus: string = 'idle';
  @State private placesError: string = '';
  @State private activeId: string = '';
  @State private listExpanded: boolean = false;
  @State private routeInfo: NearbyRouteInfo | null = null;
  @State private walkingId: string = '';
  @State private checkinId: string = '';

  aboutToAppear(): void {
    this.readNavParam();
    this.category = this.initialCategory;
    const cached: GeoPoint | null = savedGeo(10 * 60 * 1000);
    if (cached !== null) {
      this.centerLat = cached.lat;
      this.centerLng = cached.lng;
      this.accuracy = cached.accuracy;
      this.geoStatus = 'ok';
      this.loadPlaces();
    } else {
      this.locate();
    }
  }

  private readNavParam(): void {
    try {
      const nav: NearbyNavParam = this.navParam as NearbyNavParam;
      if (nav !== null && typeof nav.reminderId === 'number' && nav.reminderId > 0) {
        this.linkedReminderId = nav.reminderId;
        this.linkedReminderTitle = typeof nav.reminderTitle === 'string' ? nav.reminderTitle : '遛弯提醒';
        this.linkedPetId = typeof nav.petId === 'number' ? nav.petId : 0;
        this.initialCategory = nav.category === 'park' ? 'park' : 'medical';
      }
    } catch (err) {
      console.warn(`read nearby param failed: ${JSON.stringify(err)}`);
    }
  }

  private async locate(): Promise<void> {
    this.geoStatus = 'locating';
    this.routeInfo = null;
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const point: GeoPoint = await requestGeo(context);
      this.centerLat = point.lat;
      this.centerLng = point.lng;
      this.accuracy = point.accuracy;
      this.geoStatus = 'ok';
      this.activeId = '';
      this.loadPlaces();
    } catch (err) {
      const reason: string = err instanceof Error ? err.message : '';
      if (reason === 'denied') {
        this.geoStatus = 'denied';
        this.geoMessage = '未获得定位权限，无法查询周边资源。请在系统设置中允许「位置」。';
      } else if (reason === 'unavailable') {
        this.geoStatus = 'error';
        this.geoMessage = '定位服务未开启，请检查系统定位开关后重试。';
      } else {
        this.geoStatus = 'error';
        this.geoMessage = '定位失败，请检查系统定位服务或网络后重试。';
      }
    }
  }

  private async loadPlaces(): Promise<void> {
    if (this.centerLat === 0 && this.centerLng === 0) {
      return;
    }
    this.placesStatus = 'loading';
    try {
      this.places = await PlacesApi.nearby(this.centerLat, this.centerLng, this.category, this.radius);
      this.placesStatus = 'ok';
      this.activeId = '';
      this.listExpanded = false;
    } catch (err) {
      this.placesStatus = 'error';
      this.placesError = err instanceof Error ? err.message : '周边查询失败，请稍后重试';
    }
  }

  private setCategory(value: PlaceCategory): void {
    if (this.category === value) {
      return;
    }
    this.category = value;
    this.clearRoute();
    if (this.geoStatus === 'ok') {
      this.loadPlaces();
    }
  }

  private setRadius(value: number): void {
    if (this.radius === value) {
      return;
    }
    this.radius = value;
    if (this.geoStatus === 'ok') {
      this.loadPlaces();
    }
  }

  private categoryLabel(): string {
    return this.category === 'medical' ? '宠物医疗' : '散步公园';
  }

  private radiusLabel(): string {
    return this.radius === 1000 ? '1 公里' : this.radius === 5000 ? '5 公里' : '3 公里';
  }

  private accuracyText(): string {
    return this.accuracy > 0 ? `（±${Math.round(this.accuracy)} 米）` : '';
  }

  private typeLabel(type: string): string {
    const parts: string[] = type.split(';').filter((part: string) => part.length > 0);
    return parts.length > 0 ? parts[parts.length - 1] : '周边';
  }

  private normalizeTel(tel: string): string {
    return tel.split(';').filter((part: string) => part.length > 0).join(' / ');
  }

  private distanceText(meters: number): string {
    return meters < 1000 ? `${Math.round(meters)} 米` : `${(meters / 1000).toFixed(1)} 公里`;
  }

  private durationText(seconds: number): string {
    return `${Math.max(1, Math.round(seconds / 60))} 分钟`;
  }

  private visiblePlaces(): NearbyPlace[] {
    return this.listExpanded ? this.places : this.places.slice(0, 4);
  }

  private activePlace(): NearbyPlace | undefined {
    return this.places.find((place: NearbyPlace) => place.id === this.activeId);
  }

  private maxPlaceDistance(): number {
    let max: number = 0;
    this.places.forEach((place: NearbyPlace) => {
      if (place.distanceMeters > max) {
        max = place.distanceMeters;
      }
    });
    return max > 0 ? max : 1;
  }

  /** 将经纬度方向映射为示意图上的偏移量 */
  private pinOffsetX(place: NearbyPlace): number {
    const ratio: number = Math.min(1, place.distanceMeters / this.maxPlaceDistance());
    const distance: number = 28 + ratio * 88;
    const angle: number = Math.atan2(place.lat - this.centerLat, place.lng - this.centerLng);
    return Math.cos(angle) * distance;
  }

  private pinOffsetY(place: NearbyPlace): number {
    const ratio: number = Math.min(1, place.distanceMeters / this.maxPlaceDistance());
    const distance: number = 28 + ratio * 88;
    const angle: number = Math.atan2(place.lat - this.centerLat, place.lng - this.centerLng);
    return -Math.sin(angle) * distance;
  }

  private selectPlace(place: NearbyPlace): void {
    this.activeId = place.id;
  }

  private radiusMenu(): MenuElement[] {
    const items: MenuElement[] = [];
    const values: number[] = [1000, 3000, 5000];
    values.forEach((value: number) => {
      const label: string = value === 1000 ? '1 公里内' : value === 5000 ? '5 公里内' : '3 公里内';
      items.push({
        value: label,
        action: () => {
          this.setRadius(value);
        }
      });
    });
    return items;
  }

  private async walkTo(place: NearbyPlace): Promise<void> {
    if (this.centerLat === 0 && this.centerLng === 0) {
      return;
    }
    this.walkingId = place.id;
    this.activeId = place.id;
    try {
      const route: WalkRoute = await PlacesApi.walk(this.centerLat, this.centerLng, place.lat, place.lng);
      const info: NearbyRouteInfo = {
        place: place,
        distanceMeters: route.distanceMeters,
        durationSeconds: route.durationSeconds
      };
      this.routeInfo = info;
    } catch (err) {
      console.warn(`walk route failed: ${JSON.stringify(err)}`);
    } finally {
      this.walkingId = '';
    }
  }

  private clearRoute(): void {
    this.routeInfo = null;
  }

  private gaodeWalkUrl(): string {
    if (this.routeInfo === null) {
      return '';
    }
    const place: NearbyPlace = (this.routeInfo as NearbyRouteInfo).place;
    return `https://uri.amap.com/navigation?from=${this.centerLng},${this.centerLat},我的位置` +
      `&to=${place.lng},${place.lat},${encodeURIComponent(place.name)}&mode=walk&policy=1&src=furguardian&coordinate=gaode&callnative=0`;
  }

  private gaodeMarkerUrl(place: NearbyPlace): string {
    return `https://uri.amap.com/marker?position=${place.lng},${place.lat}&name=${encodeURIComponent(place.name)}` +
      '&src=furguardian&coordinate=gaode&callnative=0';
  }

  private openUrl(url: string): void {
    if (url.length === 0) {
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    context.openLink(url).catch((err: Object) => {
      console.warn(`open link failed: ${JSON.stringify(err)}`);
      showToast('无法打开高德地图，请确认已安装或稍后重试');
    });
  }

  private async checkinPlace(place: NearbyPlace): Promise<void> {
    if (this.linkedReminderId <= 0) {
      return;
    }
    this.checkinId = place.id;
    try {
      await ReminderApi.checkin(this.linkedReminderId, {
        doneDate: todayText(),
        note: place.name.substring(0, 255)
      });
      AppStorage.setOrCreate('fg_remindersDirty', true);
      showToast(`已用「${place.name}」完成遛弯打卡`);
      Nav.pop();
    } catch (err) {
      console.warn(`checkin failed: ${JSON.stringify(err)}`);
    } finally {
      this.checkinId = '';
    }
  }

  @Builder
  CategoryTab(label: string, value: PlaceCategory) {
    Text(label)
      .fontSize(FG.textBody)
      .fontWeight(this.category === value ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.category === value ? FG.surface : FG.inkMuted)
      .textAlign(TextAlign.Center)
      .height(32)
      .layoutWeight(1)
      .padding({ left: 12, right: 12 })
      .borderRadius(6)
      .backgroundColor(this.category === value ? FG.accent : Color.Transparent)
      .onClick(() => {
        this.setCategory(value);
      })
  }

  @Builder
  RadiusButton() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row() {
        Text(this.radiusLabel())
          .fontSize(FG.textBody)
          .fontColor(FG.ink)
        Icon({ name: 'chevron-down', iconSize: 14, color: FG.inkMuted })
          .margin({ left: 4 })
      }
      .alignItems(VerticalAlign.Center)
    }
    .height(32)
    .padding({ left: 10, right: 8 })
    .backgroundColor(FG.surface)
    .borderRadius(6)
    .border({ width: 1, color: FG.line })
    .bindMenu(this.radiusMenu())
  }

  @Builder
  MapPin(place: NearbyPlace) {
    Column() {
      Icon({
        name: this.category === 'medical' ? 'stethoscope' : 'trees',
        iconSize: this.activeId === place.id ? 14 : 12,
        color: FG.surface
      })
    }
    .width(this.activeId === place.id ? 32 : 28)
    .height(this.activeId === place.id ? 32 : 28)
    .borderRadius(this.activeId === place.id ? 16 : 14)
    .backgroundColor(this.category === 'medical' ? '#D93A3A' : FG.success)
    .border({ width: 2, color: this.activeId === place.id ? FG.accent : FG.surface })
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.25)', offsetX: 0, offsetY: 2 })
    .offset({ x: this.pinOffsetX(place), y: this.pinOffsetY(place) })
    .onClick(() => {
      this.selectPlace(place);
    })
  }

  @Builder
  MapSketch() {
    Column() {
      Row() {
        Icon({ name: 'map', iconSize: 15, color: FG.inkMuted })
        Text('位置示意')
          .fontSize(FG.textLabel)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.inkMuted)
          .margin({ left: 6 })
        Blank()
        Text(`已选 ${this.places.length} 处`)
          .fontSize(11)
          .fontColor(FG.inkMuted)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 8 })

      Stack({ alignContent: Alignment.Center }) {
        Column() {
          ForEach([0, 1, 2, 3, 4], () => {
            Row()
              .width('100%')
              .height(1)
              .backgroundColor(FG.line)
              .opacity(0.55)
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.SpaceEvenly)

        Row() {
          ForEach([0, 1, 2, 3, 4], () => {
            Column()
              .width(1)
              .height('100%')
              .backgroundColor(FG.line)
              .opacity(0.55)
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.SpaceEvenly)

        Column()
          .width(16)
          .height(16)
          .borderRadius(8)
          .backgroundColor(FG.accent)
          .border({ width: 3, color: FG.surface })
          .shadow({ radius: 6, color: 'rgba(31,92,74,0.25)', offsetX: 0, offsetY: 0 })

        ForEach(this.places.slice(0, 8), (place: NearbyPlace) => {
          this.MapPin(place)
        }, (place: NearbyPlace) => `pin-${place.id}`)
      }
      .width('100%')
      .height(220)
      .backgroundColor(FG.paper)

      if (this.activePlace() !== undefined) {
        Row() {
          Icon({
            name: this.category === 'medical' ? 'stethoscope' : 'trees',
            iconSize: 13,
            color: this.category === 'medical' ? '#D93A3A' : FG.success
          })
          Text((this.activePlace() as NearbyPlace).name)
            .fontSize(FG.textBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(FG.ink)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 6 })
          Text(this.distanceText((this.activePlace() as NearbyPlace).distanceMeters))
            .fontSize(FG.textBody)
            .fontColor(FG.inkMuted)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .border({ width: { top: 1 }, color: FG.line })
      }

      Text('示意图仅表示大致方位，未接入高德底图；点选标记可查看对应地点。')
        .fontSize(11)
        .lineHeight(16)
        .fontColor(FG.inkMuted)
        .width('100%')
        .padding({ left: 12, right: 12, top: 6, bottom: 8 })
        .backgroundColor(FG.surface)
    }
    .width('100%')
    .backgroundColor(FG.surface)
    .borderRadius(FG.radius)
    .border({ width: 1, color: FG.line })
    .clip(true)
    .margin({ bottom: 16 })
  }

  @Builder
  PlaceKind() {
    Row() {
      Icon({
        name: this.category === 'medical' ? 'stethoscope' : 'trees',
        iconSize: 12,
        color: this.category === 'medical' ? FG.danger : FG.success
      })
      Text(this.category === 'medical' ? '医院' : '公园')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.category === 'medical' ? FG.danger : FG.success)
        .margin({ left: 3 })
    }
    .height(22)
    .padding({ left: 6, right: 6 })
    .borderRadius(4)
    .backgroundColor(this.category === 'medical' ? FG.dangerSoft : FG.accentSoft)
    .border({ width: 1, color: this.category === 'medical' ? '#F2B8B5' : '#B6DDC6' })
  }

  @Builder
  PlaceCard(place: NearbyPlace) {
    Column() {
      Row() {
        this.PlaceKind()
        Text(place.name)
          .fontSize(FG.textLead)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.ink)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 6 })
          .margin({ right: 6 })
        FgChip({ label: this.typeLabel(place.type) })
        Text(this.distanceText(place.distanceMeters))
          .fontSize(FG.textBody)
          .fontColor(FG.inkMuted)
          .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (place.address !== undefined && place.address !== null && place.address.length > 0) {
        Text(place.address as string)
          .fontSize(FG.textBody)
          .fontColor(FG.inkMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 8 })
      }

      if (place.tel !== undefined && place.tel !== null && place.tel.length > 0) {
        Row() {
          Text('电话')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ right: 4 })
          Text(this.normalizeTel(place.tel as string))
            .fontSize(FG.textBody)
            .fontColor(FG.inkMuted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ top: 4 })
      }

      Row() {
        FgButton({
          label: '步行路线',
          variant: 'secondary',
          icon: 'footprints',
          small: true,
          loading: this.walkingId === place.id,
          onTap: () => {
            this.walkTo(place);
          }
        })
        if (this.linkedReminderId > 0 && this.category === 'park') {
          FgButton({
            label: '完成遛弯打卡',
            variant: 'primary',
            small: true,
            loading: this.checkinId === place.id,
            onTap: () => {
              this.checkinPlace(place);
            }
          })
        } else {
          Row() {
            Text('在高德打开')
              .fontSize(FG.textBody)
              .fontColor(FG.accent)
            Icon({ name: 'external-link', iconSize: 13, color: FG.accent })
              .margin({ left: 3 })
          }
          .margin({ left: 12 })
          .onClick(() => {
            this.openUrl(this.gaodeMarkerUrl(place));
          })
        }
      }
      .width('100%')
      .padding({ top: 10 })
      .margin({ top: 10 })
      .border({ width: { top: 1 }, color: FG.line })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(FG.s4)
    .backgroundColor(this.activeId === place.id ? FG.accentSoft : FG.surface)
    .borderRadius(FG.radius)
    .border({
      width: { left: this.activeId === place.id ? 3 : 1, top: 1, right: 1, bottom: 1 },
      color: this.activeId === place.id ? FG.accent : FG.line
    })
    .margin({ bottom: 12 })
    .onClick(() => {
      this.selectPlace(place);
    })
  }

  @Builder
  GeoStateCard() {
    Column() {
      if (this.geoStatus === 'locating') {
        Row() {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(FG.accent)
          Text('正在获取当前位置…')
            .fontSize(FG.textBody)
            .fontColor(FG.inkMuted)
            .margin({ left: 8 })
        }
        .width('100%')
        .padding(FG.s4)
        .backgroundColor(FG.surface)
        .borderRadius(FG.radius)
        .border({ width: 1, color: FG.line })
      } else {
        Column() {
          EmptyState({ variant: 'warning', description: this.geoMessage })
          FgButton({
            label: '重新定位',
            variant: 'primary',
            small: true,
            onTap: () => {
              this.locate();
            }
          })
          Text('定位需要系统允许「位置」权限，并在开启定位服务后重试。')
            .fontSize(FG.textLabel)
            .lineHeight(19)
            .fontColor(FG.inkMuted)
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })
        }
        .width('100%')
        .padding({ left: FG.s4, right: FG.s4, bottom: FG.s4 })
        .backgroundColor(FG.surface)
        .borderRadius(FG.radius)
        .border({ width: 1, color: FG.line })
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .margin({ bottom: 16 })
  }

  @Builder
  Toolbar() {
    Column() {
      Row() {
        Column()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor(FG.success)
        Text(`已定位${this.accuracyText()}`)
          .fontSize(FG.textBody)
          .fontColor(FG.ink)
          .margin({ left: 6 })
        Blank()
        FgButton({
          label: '重新定位',
          variant: 'secondary',
          icon: 'locate-fixed',
          small: true,
          onTap: () => {
            this.locate();
          }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Row() {
          this.CategoryTab('宠物医疗', 'medical')
          this.CategoryTab('散步公园', 'park')
        }
        .layoutWeight(1)
        .height(36)
        .padding(2)
        .backgroundColor(FG.paper)
        .borderRadius(FG.radius)
        .border({ width: 1, color: FG.line })

        this.RadiusButton()
      }
      .width('100%')
      .margin({ top: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(FG.s4)
    .backgroundColor(FG.surface)
    .borderRadius(FG.radius)
    .border({ width: 1, color: FG.line })
    .margin({ bottom: 16 })
  }

  @Builder
  RouteBar() {
    Column() {
      Row() {
        Icon({ name: 'footprints', iconSize: 20, color: FG.accent })
        Column() {
          Text(`步行至 ${(this.routeInfo as NearbyRouteInfo).place.name}`)
            .fontSize(FG.textBody)
            .fontWeight(FontWeight.Medium)
            .fontColor(FG.ink)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(`全程 ${this.distanceText((this.routeInfo as NearbyRouteInfo).distanceMeters)} · 约 ${this.durationText((this.routeInfo as NearbyRouteInfo).durationSeconds)}`)
            .fontSize(FG.textBody)
            .fontColor(FG.inkMuted)
            .margin({ top: 2 })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Row() {
          Text('在高德步行导航')
            .fontSize(FG.textBody)
            .fontColor(FG.accent)
          Icon({ name: 'external-link', iconSize: 13, color: FG.accent })
            .margin({ left: 3 })
        }
        .onClick(() => {
          this.openUrl(this.gaodeWalkUrl());
        })
        Blank()
        Text('清除路线')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .onClick(() => {
            this.clearRoute();
          })
      }
      .width('100%')
      .margin({ top: 10 })
      .padding({ top: 8 })
      .border({ width: { top: 1 }, color: FG.line })
    }
    .width('100%')
    .padding(FG.s4)
    .backgroundColor(FG.surface)
    .borderRadius(FG.radius)
    .border({ width: 1, color: FG.line })
    .margin({ bottom: 16 })
  }

  build() {
    Scroll() {
      Column() {
        PageHeader({
          title: '周边资源',
          breadcrumb: '工具 / 周边资源',
          description: '以当前位置为圆心查找宠物医院等医疗资源与可散步的公园，并可查看步行路线。',
          backLabel: this.showBack ? '提醒' : '',
          onBack: () => {
            Nav.pop();
          }
        })

        if (this.linkedReminderId > 0) {
          Row() {
            Icon({ name: 'map-pin', iconSize: 20, color: FG.accent })
              .margin({ top: 2 })
            Column() {
              Text(`正在为「${this.linkedReminderTitle.length > 0 ? this.linkedReminderTitle : '遛弯提醒'}」找遛弯地点`)
                .fontSize(FG.textBody)
                .fontWeight(FontWeight.Medium)
                .fontColor(FG.ink)
                .width('100%')
              Text('选一处公园，走完后点卡片上的「完成遛弯打卡」，地点会记进这次打卡的备注。')
                .fontSize(FG.textLabel)
                .lineHeight(19)
                .fontColor(FG.inkMuted)
                .width('100%')
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 8 })
          }
          .width('100%')
          .padding(FG.s4)
          .backgroundColor(FG.surface)
          .borderRadius(FG.radius)
          .border({
            width: { left: 3, top: 1, right: 1, bottom: 1 },
            color: FG.accent
          })
          .margin({ bottom: 16 })
        }

        if (this.geoStatus !== 'ok') {
          this.GeoStateCard()
        } else {
          this.Toolbar()
          this.MapSketch()

          if (this.routeInfo !== null) {
            this.RouteBar()
          }

          Row() {
            Text(`${this.categoryLabel()} · ${this.radiusLabel()}内`)
              .fontSize(FG.textH3)
              .fontWeight(FontWeight.Medium)
              .fontFamily(FG.serif)
              .fontColor(FG.ink)
            if (this.placesStatus === 'ok') {
              Text(`${this.places.length} 处`)
                .fontSize(FG.textLabel)
                .fontColor(FG.inkMuted)
                .margin({ left: 8 })
                .padding({ left: 8, right: 8 })
                .height(22)
                .borderRadius(6)
                .backgroundColor(FG.paper)
                .border({ width: 1, color: FG.line })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ bottom: 12 })

          if (this.placesStatus === 'loading') {
            Row() {
              LoadingProgress()
                .width(18)
                .height(18)
                .color(FG.accent)
              Text(`正在查询周边${this.categoryLabel()}…`)
                .fontSize(FG.textBody)
                .fontColor(FG.inkMuted)
                .margin({ left: 8 })
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
          } else if (this.placesStatus === 'error') {
            Row() {
              Text(this.placesError)
                .fontSize(FG.textBody)
                .fontColor(FG.danger)
                .layoutWeight(1)
              FgButton({
                label: '重试',
                variant: 'secondary',
                small: true,
                onTap: () => {
                  this.loadPlaces();
                }
              })
            }
            .width('100%')
            .padding(FG.s4)
            .backgroundColor(FG.dangerSoft)
            .borderRadius(FG.radius)
            .border({ width: 1, color: '#F2B8B5' })
          } else if (this.places.length === 0) {
            Column() {
              EmptyState({ variant: 'search', description: `${this.radiusLabel()}内没有找到${this.categoryLabel()}。` })
              if (this.radius < 5000) {
                FgButton({
                  label: '扩大到 5 公里',
                  variant: 'secondary',
                  small: true,
                  onTap: () => {
                    this.setRadius(5000);
                  }
                })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          } else {
            ForEach(this.visiblePlaces(), (place: NearbyPlace) => {
              this.PlaceCard(place)
            }, (place: NearbyPlace) => `place-${place.id}`)

            if (this.places.length > 4) {
              Row() {
                Text(this.listExpanded ? '收起' : `展开其余 ${this.places.length - 4} 处`)
                  .fontSize(FG.textBody)
                  .fontColor(FG.accent)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding({ top: 4, bottom: 12 })
              .onClick(() => {
                this.listExpanded = !this.listExpanded;
              })
            }
          }

          DisclaimerBar({
            text: '周边信息来自高德地图开放平台，距离为直线距离；步行路线为高德规划结果，出行请以实际路况为准。'
          })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 24, bottom: 48 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }
}
