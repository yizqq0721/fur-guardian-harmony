import { http } from '@kit.NetworkKit';
import { promptAction } from '@kit.ArkUI';
import { AppConfig } from '../common/AppConfig';
import { ApiResult } from '../models/Types';

export class ApiError extends Error {
  code: number = 0;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
  }
}

export function showToast(message: string): void {
  try {
    promptAction.showToast({ message: message, duration: 2500 });
  } catch (err) {
    console.error(`showToast failed: ${JSON.stringify(err)}`);
  }
}

export function getToken(): string {
  const token: string | undefined = AppStorage.get<string>('fg_token');
  return token ?? '';
}

export function clearAuthState(): void {
  AppStorage.setOrCreate('fg_token', '');
  AppStorage.setOrCreate('fg_userId', 0);
  AppStorage.setOrCreate('fg_nickname', '');
  AppStorage.setOrCreate('fg_isAdmin', false);
  AppStorage.setOrCreate('fg_location', '');
  AppStorage.setOrCreate('fg_pets', [] as Object[]);
  AppStorage.setOrCreate('fg_petsLoaded', false);
  AppStorage.setOrCreate('fg_currentPetId', 0);
}

function handleUnauthorized(): void {
  clearAuthState();
  showToast('登录已过期，请重新登录');
}

/** 查询参数构造器 */
export class Params {
  private parts: string[] = [];

  add(key: string, value?: string | number | boolean | null): Params {
    if (value === undefined || value === null) {
      return this;
    }
    if (typeof value === 'string' && value.length === 0) {
      return this;
    }
    this.parts.push(`${key}=${encodeURIComponent(String(value))}`);
    return this;
  }

  build(): string {
    return this.parts.length > 0 ? `?${this.parts.join('&')}` : '';
  }
}

export async function apiRequest<T>(
  method: http.RequestMethod,
  path: string,
  body?: Object | null,
  silent: boolean = false
): Promise<T> {
  const httpRequest: http.HttpRequest = http.createHttp();
  try {
    const header: Record<string, string> = {};
    header['Content-Type'] = 'application/json';
    const token: string = getToken();
    if (token.length > 0) {
      header['Authorization'] = `Bearer ${token}`;
    }

    const options: http.HttpRequestOptions = {
      method: method,
      header: header,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 60000,
      extraData: body === undefined || body === null ? undefined : JSON.stringify(body)
    };

    const response: http.HttpResponse = await httpRequest.request(AppConfig.API_BASE_URL + path, options);
    const statusCode: number = Number(response.responseCode);
    const raw: string = response.result as string;

    if (statusCode === 401) {
      handleUnauthorized();
      throw new ApiError(401, '登录已过期，请重新登录');
    }

    if (statusCode < 200 || statusCode >= 300) {
      if (!silent) {
        showToast(statusCode === 500 ? '服务繁忙，请稍后再试' : '网络异常，请稍后再试');
      }
      throw new ApiError(statusCode, `HTTP ${statusCode}`);
    }

    const payload: ApiResult<T> = JSON.parse(raw) as ApiResult<T>;
    if (payload.code === 200) {
      return payload.data;
    }
    if (payload.code === 401) {
      handleUnauthorized();
      throw new ApiError(401, payload.message);
    }
    if (!silent) {
      showToast(payload.message && payload.message.length > 0 ? payload.message : '请求失败');
    }
    throw new ApiError(payload.code, payload.message);
  } catch (err) {
    if (err instanceof ApiError) {
      throw err;
    }
    console.error(`request ${path} failed: ${JSON.stringify(err)}`);
    if (!silent) {
      showToast('网络异常，请稍后再试');
    }
    throw new ApiError(-1, '网络异常，请稍后再试');
  } finally {
    httpRequest.destroy();
  }
}

/** multipart 上传（头像等），由 http 模块自动生成 boundary */
export async function apiUpload<T>(
  path: string,
  data: ArrayBuffer,
  fileName: string,
  contentType: string
): Promise<T> {
  const httpRequest: http.HttpRequest = http.createHttp();
  try {
    const header: Record<string, string> = {};
    const token: string = getToken();
    if (token.length > 0) {
      header['Authorization'] = `Bearer ${token}`;
    }

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: header,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 60000,
      multiFormDataList: [
        {
          name: 'file',
          contentType: contentType,
          remoteFileName: fileName,
          data: data
        }
      ]
    };

    const response: http.HttpResponse = await httpRequest.request(AppConfig.API_BASE_URL + path, options);
    const statusCode: number = Number(response.responseCode);
    const raw: string = response.result as string;

    if (statusCode === 401) {
      handleUnauthorized();
      throw new ApiError(401, '登录已过期，请重新登录');
    }
    if (statusCode < 200 || statusCode >= 300) {
      showToast('上传失败，请稍后再试');
      throw new ApiError(statusCode, `HTTP ${statusCode}`);
    }

    const payload: ApiResult<T> = JSON.parse(raw) as ApiResult<T>;
    if (payload.code === 200) {
      return payload.data;
    }
    showToast(payload.message && payload.message.length > 0 ? payload.message : '上传失败');
    throw new ApiError(payload.code, payload.message);
  } catch (err) {
    if (err instanceof ApiError) {
      throw err;
    }
    console.error(`upload ${path} failed: ${JSON.stringify(err)}`);
    showToast('上传失败，请检查网络');
    throw new ApiError(-1, '上传失败');
  } finally {
    httpRequest.destroy();
  }
}

export function get<T>(path: string, silent: boolean = false): Promise<T> {
  return apiRequest<T>(http.RequestMethod.GET, path, null, silent);
}

export function post<T>(path: string, body?: Object | null, silent: boolean = false): Promise<T> {
  return apiRequest<T>(http.RequestMethod.POST, path, body ?? null, silent);
}

export function put<T>(path: string, body?: Object | null, silent: boolean = false): Promise<T> {
  return apiRequest<T>(http.RequestMethod.PUT, path, body ?? null, silent);
}

export function del<T>(path: string, silent: boolean = false): Promise<T> {
  return apiRequest<T>(http.RequestMethod.DELETE, path, null, silent);
}
