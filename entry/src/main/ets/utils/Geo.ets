import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { geoLocationManager } from '@kit.LocationKit';
import { PlacesApi, UserApi } from '../api/Api';
import { GeoAddress, UserProfile } from '../models/Types';
import { showToast } from './Http';

export interface GeoPoint {
  lat: number;
  lng: number;
  at: number;
  accuracy: number;
}

const PI: number = Math.PI;
const AXIS: number = 6378245.0;
const ECCENTRICITY: number = 0.00669342162296594323;

function outOfChina(lng: number, lat: number): boolean {
  return lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;
}

function transformLat(x: number, y: number): number {
  let ret: number = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * Math.sqrt(Math.abs(x));
  ret += ((20.0 * Math.sin(6.0 * x * PI) + 20.0 * Math.sin(2.0 * x * PI)) * 2.0) / 3.0;
  ret += ((20.0 * Math.sin(y * PI) + 40.0 * Math.sin((y / 3.0) * PI)) * 2.0) / 3.0;
  ret += ((160.0 * Math.sin((y / 12.0) * PI) + 320 * Math.sin((y * PI) / 30.0)) * 2.0) / 3.0;
  return ret;
}

function transformLng(x: number, y: number): number {
  let ret: number = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * Math.sqrt(Math.abs(x));
  ret += ((20.0 * Math.sin(6.0 * x * PI) + 20.0 * Math.sin(2.0 * x * PI)) * 2.0) / 3.0;
  ret += ((20.0 * Math.sin(x * PI) + 40.0 * Math.sin((x / 3.0) * PI)) * 2.0) / 3.0;
  ret += ((150.0 * Math.sin((x / 12.0) * PI) + 300.0 * Math.sin((x / 30.0) * PI)) * 2.0) / 3.0;
  return ret;
}

/** WGS-84 → GCJ-02，高德底图与服务端周边接口都使用火星坐标 */
export function wgs84ToGcj02(lng: number, lat: number): number[] {
  if (outOfChina(lng, lat)) {
    return [lng, lat];
  }
  let dLat: number = transformLat(lng - 105.0, lat - 35.0);
  let dLng: number = transformLng(lng - 105.0, lat - 35.0);
  const radLat: number = (lat / 180.0) * PI;
  let magic: number = Math.sin(radLat);
  magic = 1 - ECCENTRICITY * magic * magic;
  const sqrtMagic: number = Math.sqrt(magic);
  dLat = (dLat * 180.0) / (((AXIS * (1 - ECCENTRICITY)) / (magic * sqrtMagic)) * PI);
  dLng = (dLng * 180.0) / ((AXIS / sqrtMagic) * Math.cos(radLat) * PI);
  return [lng + dLng, lat + dLat];
}

export function saveGeo(lat: number, lng: number): void {
  AppStorage.setOrCreate('fg_geoLat', lat);
  AppStorage.setOrCreate('fg_geoLng', lng);
  AppStorage.setOrCreate('fg_geoAt', Date.now());
}

export function savedGeo(maxAgeMs: number = 0): GeoPoint | null {
  const lat: number = AppStorage.get<number>('fg_geoLat') ?? 0;
  const lng: number = AppStorage.get<number>('fg_geoLng') ?? 0;
  const at: number = AppStorage.get<number>('fg_geoAt') ?? 0;
  if (lat === 0 && lng === 0) {
    return null;
  }
  if (maxAgeMs > 0 && Date.now() - at > maxAgeMs) {
    return null;
  }
  const point: GeoPoint = { lat: lat, lng: lng, at: at, accuracy: 0 };
  return point;
}

function errText(err: Object): string {
  if (err instanceof Error) {
    return err.message;
  }
  return JSON.stringify(err);
}

function hasPermission(atManager: abilityAccessCtrl.AtManager, tokenId: number, permission: Permissions): boolean {
  try {
    return atManager.checkAccessTokenSync(tokenId, permission) === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  } catch (err) {
    console.warn(`[FG/geo] check ${permission} failed: ${errText(err)}`);
    return false;
  }
}

async function fixOnce(
  priority: geoLocationManager.LocationRequestPriority,
  timeoutMs: number
): Promise<geoLocationManager.Location | null> {
  const request: geoLocationManager.CurrentLocationRequest = {
    priority: priority,
    scenario: geoLocationManager.LocationRequestScenario.DAILY_LIFE_SERVICE,
    timeoutMs: timeoutMs
  };
  try {
    const location: geoLocationManager.Location = await geoLocationManager.getCurrentLocation(request);
    console.info(`[FG/geo] fix ok priority=${priority} lat=${location.latitude} lng=${location.longitude} acc=${location.accuracy}`);
    return location;
  } catch (err) {
    console.warn(`[FG/geo] fix failed priority=${priority}: ${errText(err)}`);
    return null;
  }
}

export async function requestGeo(context: common.UIAbilityContext): Promise<GeoPoint> {
  let enabled: boolean = true;
  try {
    enabled = geoLocationManager.isLocationEnabled();
  } catch (err) {
    console.warn(`[FG/geo] isLocationEnabled failed: ${errText(err)}`);
  }
  console.info(`[FG/geo] location service enabled=${enabled}`);
  if (!enabled) {
    throw new Error('unavailable');
  }
  const atManager = abilityAccessCtrl.createAtManager();
  let already: boolean = false;
  try {
    const tokenId: number =
      bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).appInfo.accessTokenId;
    already = hasPermission(atManager, tokenId, 'ohos.permission.LOCATION') ||
      hasPermission(atManager, tokenId, 'ohos.permission.APPROXIMATELY_LOCATION');
  } catch (err) {
    console.warn(`[FG/geo] read tokenId failed: ${errText(err)}`);
  }
  let granted: boolean = already;
  if (!granted) {
    const permissions: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
    try {
      const result = await atManager.requestPermissionsFromUser(context, permissions);
      console.info(`[FG/geo] permission results=${JSON.stringify(result.authResults)}`);
      result.authResults.forEach((code: number) => {
        if (code === 0) {
          granted = true;
        }
      });
    } catch (err) {
      console.warn(`[FG/geo] requestPermissionsFromUser failed: ${errText(err)}`);
    }
  }
  if (!granted) {
    throw new Error('denied');
  }
  let location: geoLocationManager.Location | null | undefined =
    await fixOnce(geoLocationManager.LocationRequestPriority.FIRST_FIX, 10000);
  if (location === null) {
    location = await fixOnce(geoLocationManager.LocationRequestPriority.ACCURACY, 8000);
  }
  if (location === null) {
    try {
      location = geoLocationManager.getLastLocation();
      console.info(`[FG/geo] last location=${location === undefined ? 'undefined' : `${location.latitude},${location.longitude}`}`);
    } catch (err) {
      console.warn(`[FG/geo] getLastLocation failed: ${errText(err)}`);
    }
  }
  if (location === undefined || location === null || (location.latitude === 0 && location.longitude === 0)) {
    const cached: GeoPoint | null = savedGeo(24 * 60 * 60 * 1000);
    if (cached !== null) {
      console.info('[FG/geo] fallback to cached point');
      return cached;
    }
    console.warn('[FG/geo] no fix available (emulator needs injected GPS: hdc shell geo fix <lng> <lat>)');
    throw new Error('timeout');
  }
  const converted: number[] = wgs84ToGcj02(location.longitude, location.latitude);
  saveGeo(converted[1], converted[0]);
  const point: GeoPoint = { lat: converted[1], lng: converted[0], at: Date.now(), accuracy: location.accuracy };
  console.info(`[FG/geo] converted gcj02=${point.lat},${point.lng}`);
  return point;
}

/** 定位 + 反查区县 + 保存到用户资料，供设置/用户信息/周边共用 */
export async function locateAndSave(context: common.UIAbilityContext): Promise<GeoAddress | null> {
  try {
    const point: GeoPoint = await requestGeo(context);
    const address: GeoAddress = await PlacesApi.regeo(point.lat, point.lng);
    const profile: UserProfile = await UserApi.update({ location: address.label });
    AppStorage.setOrCreate('fg_nickname', profile.nickname ?? '');
    AppStorage.setOrCreate('fg_location', profile.location ?? address.label);
    showToast(`当前位置：${address.label}`);
    return address;
  } catch (err) {
    const reason: string = err instanceof Error ? err.message : '';
    console.warn(`[FG/geo] locateAndSave failed: ${errText(err)}`);
    if (reason === 'denied') {
      showToast('定位权限被拒绝，请在系统设置中允许访问位置');
    } else if (reason === 'unavailable') {
      showToast('定位服务未开启，请检查系统定位开关');
    } else if (reason === 'timeout') {
      showToast('未获取到定位结果，请检查定位服务或稍后重试');
    } else {
      showToast(`定位失败：${reason.length > 0 ? reason : '请稍后重试'}`);
    }
    return null;
  }
}
