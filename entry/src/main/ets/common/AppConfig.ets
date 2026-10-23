/**
 * 联调地址：模拟器/真机需能访问到运行 Spring Boot 的电脑。
 * 更换网络后，把这里改成电脑当前的局域网 IPv4（Windows: ipconfig）。
 */
export class AppConfig {
  static readonly API_BASE_URL: string = 'http://10.101.187.229:8080';
  static readonly APP_NAME: string = 'FurGuardian';
}
