import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { AppConfig } from '../common/AppConfig';
import { ApiError, clearAuthState, getToken } from './Http';

export class SseFrame {
  event: string = 'message';
  data: string = '';
}

function parseFrame(raw: string): SseFrame {
  const frame: SseFrame = new SseFrame();
  const data: string[] = [];
  raw.split('\n').forEach((line: string) => {
    if (line.startsWith('event:')) {
      frame.event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      let value: string = line.substring(5);
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }
      data.push(value);
    }
  });
  frame.data = data.join('\n');
  return frame;
}

/** 带 Authorization 的 SSE 读取（HarmonyOS 无 EventSource），按空行分帧回调 */
export async function sseRequest(path: string, onFrame: (frame: SseFrame) => void): Promise<void> {
  const request: http.HttpRequest = http.createHttp();
  const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
  const header: Record<string, string> = {};
  header['Accept'] = 'text/event-stream';
  const token: string = getToken();
  if (token.length > 0) {
    header['Authorization'] = `Bearer ${token}`;
  }

  let buffer: string = '';
  request.on('dataReceive', (data: ArrayBuffer) => {
    buffer += decoder.decodeToString(new Uint8Array(data), { stream: true });
    buffer = buffer.replace(/\r\n/g, '\n');
    let boundary: number = buffer.indexOf('\n\n');
    while (boundary >= 0) {
      const frame: SseFrame = parseFrame(buffer.substring(0, boundary));
      buffer = buffer.substring(boundary + 2);
      if (frame.data.length > 0) {
        onFrame(frame);
      }
      boundary = buffer.indexOf('\n\n');
    }
  });

  try {
    const code: number = await request.requestInStream(AppConfig.API_BASE_URL + path, {
      method: http.RequestMethod.GET,
      header: header,
      connectTimeout: 15000,
      readTimeout: 90000
    });
    if (code === 401) {
      clearAuthState();
      throw new ApiError(401, '登录已过期，请重新登录');
    }
    if (code < 200 || code >= 300) {
      throw new ApiError(code, `HTTP ${code}`);
    }
  } finally {
    request.off('dataReceive');
    request.destroy();
  }
}
