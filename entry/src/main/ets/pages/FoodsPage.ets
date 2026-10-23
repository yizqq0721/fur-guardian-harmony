import { FoodApi } from '../api/Api';
import { FG } from '../common/Theme';
import { EmptyState } from '../components/EmptyState';
import { FgButton } from '../components/FgButton';
import { FgChip } from '../components/FgChip';
import { Icon } from '../components/Icon';
import { PageHeader } from '../components/PageHeader';
import { Food, SelectOption } from '../models/Types';
import { FOOD_TYPE_OPTIONS, foodTypeLabel, lifeStageLabel, speciesScopeLabel } from '../utils/Constants';
import { fromNow } from '../utils/Format';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';

class FoodFilterChip {
  value: string;
  label: string;

  constructor(value: string, label: string) {
    this.value = value;
    this.label = label;
  }
}

const PAGE_SIZE: number = 20;
const PRODUCT_TYPE_CHIPS: FoodFilterChip[] = [
  new FoodFilterChip('', '全部'),
  new FoodFilterChip('COMPLETE', '全价'),
  new FoodFilterChip('COMPLEMENTARY', '补充'),
  new FoodFilterChip('SNACK', '零食')
];

/** 与 Vue FoodsView 的移动端样式一致：搜索 + 筛选 chip + 卡片列表 */
@Component
export struct FoodsPage {
  @State private loading: boolean = true;
  @State private records: Food[] = [];
  @State private total: number = 0;
  @State private page: number = 1;
  @State private keywordInput: string = '';
  @State private keyword: string = '';
  @State private foodTypeFilter: string = '';
  @State private productTypeFilter: string = '';
  @State private error: string = '';
  @StorageLink('fg_foodsDirty') @Watch('onFoodsDirty') foodsDirty: boolean = false;

  aboutToAppear(): void {
    if (this.foodsDirty) {
      this.foodsDirty = false;
    }
    this.fetchList();
  }

  private onFoodsDirty(): void {
    if (this.foodsDirty) {
      this.foodsDirty = false;
      this.fetchList();
    }
  }

  private async fetchList(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const res = await FoodApi.list({
        page: this.page,
        size: PAGE_SIZE,
        keyword: this.keyword.length > 0 ? this.keyword : undefined
      });
      this.records = res.records ?? [];
      this.total = res.total ?? 0;
    } catch (err) {
      console.error(`load foods failed: ${JSON.stringify(err)}`);
      this.records = [];
      this.total = 0;
      this.error = '食品库加载失败，请检查网络后重试';
    } finally {
      this.loading = false;
    }
  }

  private search(): void {
    this.page = 1;
    this.keyword = this.keywordInput.trim();
    this.fetchList();
  }

  private clearFilters(): void {
    this.foodTypeFilter = '';
    this.productTypeFilter = '';
  }

  private isFiltering(): boolean {
    return this.foodTypeFilter.length > 0 || this.productTypeFilter.length > 0;
  }

  private visible(): Food[] {
    return this.records.filter((food: Food) =>
      (this.foodTypeFilter.length === 0 || food.foodType === this.foodTypeFilter) &&
      (this.productTypeFilter.length === 0 || food.productType === this.productTypeFilter)
    );
  }

  private totalPages(): number {
    return Math.max(1, Math.ceil(this.total / PAGE_SIZE));
  }

  private goPage(next: number): void {
    if (next < 1 || next > this.totalPages() || next === this.page) {
      return;
    }
    this.page = next;
    this.fetchList();
  }

  private productShort(value?: string): string {
    if (value === 'COMPLETE') {
      return '全价';
    }
    if (value === 'COMPLEMENTARY') {
      return '补充';
    }
    if (value === 'SNACK') {
      return '零食';
    }
    return '';
  }

  private foodTitle(food: Food): string {
    return `${food.brand !== undefined && food.brand.length > 0 ? `${food.brand} ` : ''}${food.name}`;
  }

  private ingredientsText(food: Food): string {
    const text: string = food.ingredients ?? '';
    return text.length > 30 ? text.substring(0, 30) : text;
  }

  private proteinDm(food: Food): string {
    const protein: number | undefined = food.nutrients?.crudeProteinMin;
    const moisture: number | undefined = food.nutrients?.moistureMax;
    if (protein === undefined || moisture === undefined) {
      return '—';
    }
    const dm: number = 100 - moisture;
    if (dm <= 0) {
      return '—';
    }
    return ((protein / dm) * 100).toFixed(1);
  }

  private updateTime(food: Food): string {
    return fromNow(food.updatedAt ?? food.createdAt);
  }

  private stageText(food: Food): string {
    const scope: string = speciesScopeLabel(food.speciesScope);
    const stage: string = lifeStageLabel(food.lifeStage);
    return `${scope.length > 0 ? scope : '—'} · ${stage.length > 0 ? stage : '—'}`;
  }

  private confirmRemove(food: Food): void {
    AlertDialog.show({
      title: '删除确认',
      message: `确定删除「${food.name}」吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: FG.danger,
        action: () => {
          this.remove(food);
        }
      }
    });
  }

  private async remove(food: Food): Promise<void> {
    try {
      await FoodApi.remove(food.id);
      showToast('已删除');
      this.fetchList();
    } catch (err) {
      console.error(`remove food failed: ${JSON.stringify(err)}`);
    }
  }

  @Builder
  Chip(label: string, active: boolean, onTap: () => void) {
    Text(label)
      .fontSize(FG.textBody)
      .fontWeight(active ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(active ? FG.accent : FG.inkMuted)
      .height(40)
      .padding({ left: 12, right: 12 })
      .backgroundColor(active ? FG.accentSoft : FG.surface)
      .borderRadius(FG.radius)
      .border({ width: active ? 0 : 1, color: active ? '#00000000' : FG.line })
      .textAlign(TextAlign.Center)
      .margin({ left: 8, bottom: 8 })
      .onClick(onTap)
  }

  @Builder
  ChipRowCaption(caption: string) {
    Text(caption)
      .fontSize(FG.textLabel)
      .fontWeight(FontWeight.Medium)
      .letterSpacing(0.5)
      .fontColor(FG.inkMuted)
      .width(32)
  }

  @Builder
  SearchBox() {
    Row() {
      Icon({ name: 'search', iconSize: 18, color: FG.inkMuted })
      TextInput({ text: this.keywordInput, placeholder: '搜索品牌或名称' })
        .layoutWeight(1)
        .height(44)
        .fontSize(15)
        .fontColor(FG.ink)
        .placeholderColor(FG.inkMuted)
        .backgroundColor('#00000000')
        .padding({ left: 8, right: 4 })
        .enterKeyType(EnterKeyType.Search)
        .onChange((value: string) => {
          this.keywordInput = value;
        })
        .onSubmit(() => {
          this.search();
        })
      if (this.keywordInput.length > 0) {
        Row() {
          Icon({ name: 'x', iconSize: 15, color: FG.inkMuted })
        }
        .width(40)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.keywordInput = '';
          if (this.keyword.length > 0) {
            this.search();
          }
        })
      }
    }
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 4 })
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
  }

  @Builder
  MetaCell(label: string, value: string, leftMargin: number) {
    Column() {
      Text(label)
        .fontSize(11)
        .fontColor(FG.inkMuted)
        .width('100%')
      Text(value)
        .fontSize(13)
        .fontColor(FG.ink)
        .margin({ top: 2 })
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .margin({ left: leftMargin })
  }

  @Builder
  FoodCard(food: Food, isLast: boolean) {
    Column() {
      Row() {
        Text(this.foodTitle(food))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(FG.ink)
          .lineHeight(22)
          .layoutWeight(1)
        if (this.productShort(food.productType).length > 0) {
          FgChip({
            label: this.productShort(food.productType),
            tone: food.productType === 'COMPLETE' ? 'ok' : 'warn'
          })
            .margin({ left: 8 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.ingredientsText(food).length > 0) {
        Text(this.ingredientsText(food))
          .fontSize(FG.textLabel)
          .lineHeight(19)
          .fontColor(FG.inkMuted)
          .margin({ top: 4 })
          .width('100%')
      }

      Row() {
        this.MetaCell('类型', foodTypeLabel(food.foodType).length > 0 ? foodTypeLabel(food.foodType) : (food.foodType ?? '—'), 0)
        this.MetaCell('适用阶段', this.stageText(food), 12)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ top: 12 })

      Row() {
        this.MetaCell('代谢能', food.labeledMeKcal !== undefined && food.labeledMeKcal !== null ? `${food.labeledMeKcal} kcal/kg` : '未标注', 0)
        this.MetaCell('粗蛋白 %DM', this.proteinDm(food), 12)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ top: 8 })

      Row() {
        this.MetaCell('更新时间', this.updateTime(food), 0)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ top: 8 })

      if (food.userId !== undefined && food.userId !== null) {
        Row() {
          Text('编辑')
            .fontSize(13)
            .fontColor(FG.accent)
            .height(40)
            .padding({ left: 8, right: 8 })
            .onClick(() => {
              Nav.push('FoodForm', food.id);
            })
          Text('删除')
            .fontSize(13)
            .fontColor(FG.danger)
            .height(40)
            .padding({ left: 8, right: 8 })
            .margin({ left: 4 })
            .onClick(() => {
              this.confirmRemove(food);
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .margin({ top: 4 })
      }

      if (!isLast) {
        Divider()
          .color(FG.line)
          .strokeWidth(1)
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding({ top: 16, bottom: 8 })
  }

  @Builder
  FootNote() {
    Column() {
      Text('粗蛋白 %DM ＝ 粗蛋白 ≥% ÷ (100 − 水分 %) × 100')
        .fontFamily(FG.mono)
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .lineHeight(19)
        .width('100%')
      Text('全价＝可作唯一主食，补充／零食＝不可作唯一主食。')
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .lineHeight(19)
        .margin({ top: 4 })
        .width('100%')
      if (this.isFiltering()) {
        Text(`类型／性质筛选作用于本页 ${this.records.length} 条记录，换页后重新计算。`)
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .lineHeight(19)
          .margin({ top: 4 })
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 16, bottom: 16 })
  }

  @Builder
  PagerRow() {
    Row() {
      Text(`共 ${this.total} 条`)
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
      Blank()
      Text('上一页')
        .fontSize(13)
        .fontColor(this.page > 1 ? FG.ink : '#B9B6AE')
        .height(40)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          this.goPage(this.page - 1);
        })
      Text(`${this.page} / ${this.totalPages()}`)
        .fontFamily(FG.mono)
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .margin({ left: 4, right: 4 })
      Text('下一页')
        .fontSize(13)
        .fontColor(this.page < this.totalPages() ? FG.ink : '#B9B6AE')
        .height(40)
        .padding({ left: 10, right: 10 })
        .onClick(() => {
          this.goPage(this.page + 1);
        })
    }
    .width('100%')
    .padding({ top: 4, bottom: 8 })
    .border({ width: { top: 1 }, color: FG.line })
  }

  @Builder
  ListCard() {
    Column() {
      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(FG.accent)
          Text('正在加载食品库…')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ top: 8 })
        }
        .width('100%')
        .padding({ top: 48, bottom: 48 })
        .alignItems(HorizontalAlign.Center)
      } else if (this.error.length > 0) {
        Column() {
          Text(this.error)
            .fontSize(13)
            .fontColor(FG.danger)
            .width('100%')
          FgButton({
            label: '重新加载',
            variant: 'secondary',
            onTap: () => {
              this.fetchList();
            }
          })
            .margin({ top: 12 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .border({ width: { left: 2 }, color: FG.danger })
        .padding({ left: 12, top: 24, bottom: 24 })
      } else if (this.visible().length === 0) {
        Column() {
          EmptyState({
            variant: 'foods',
            description: this.isFiltering() ? '当前筛选没有匹配的食品' : '食品库还是空的，录入第一袋粮'
          })
          if (this.isFiltering()) {
            FgButton({
              label: '清除筛选',
              variant: 'secondary',
              onTap: () => {
                this.clearFilters();
              }
            })
          } else {
            FgButton({
              label: '录入食品',
              variant: 'primary',
              onTap: () => {
                Nav.push('FoodForm');
              }
            })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 16 })
      } else {
        ForEach(this.visible(), (food: Food, index: number) => {
          this.FoodCard(food, index === this.visible().length - 1)
        }, (food: Food) => `food-${food.id}`)
      }

      if (!this.loading) {
        this.FootNote()
        if (this.visible().length > 0) {
          this.PagerRow()
        }
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
  }

  build() {
    Scroll() {
      Column() {
        PageHeader({
          title: '我的食品库',
          breadcrumb: '食品库',
          description: '把包装袋上的保证值录进来，营养方案才能逐项对照国标判定；未标注的项留空即可。'
        })

        Column() {
          this.SearchBox()

          Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
            this.ChipRowCaption('类型')
            this.Chip('全部', this.foodTypeFilter === '', () => {
              this.foodTypeFilter = '';
            })
            ForEach(FOOD_TYPE_OPTIONS, (option: SelectOption) => {
              this.Chip(option.label, this.foodTypeFilter === option.value, () => {
                this.foodTypeFilter = option.value;
              })
            }, (option: SelectOption) => `ft-${option.value}`)
          }
          .width('100%')
          .margin({ top: 4 })

          Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
            this.ChipRowCaption('性质')
            ForEach(PRODUCT_TYPE_CHIPS, (chip: FoodFilterChip) => {
              this.Chip(chip.label, this.productTypeFilter === chip.value, () => {
                this.productTypeFilter = chip.value;
              })
            }, (chip: FoodFilterChip) => `pt-${chip.value}`)
          }
          .width('100%')

          FgButton({
            label: '录入食品',
            variant: 'primary',
            fillWidth: true,
            onTap: () => {
              Nav.push('FoodForm');
            }
          })
            .margin({ top: 4 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: 16 })

        this.ListCard()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 24, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.TopStart)
  }
}
