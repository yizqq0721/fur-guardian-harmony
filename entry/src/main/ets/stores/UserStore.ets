import { AuthApi, UserApi } from '../api/Api';
import { LoginResp, UserProfile } from '../models/Types';
import { PetStore } from './PetStore';

export class UserStore {
  static async login(username: string, password: string): Promise<LoginResp> {
    const resp: LoginResp = await AuthApi.login({ username: username, password: password });
    UserStore.applyLogin(resp);
    return resp;
  }

  static async register(username: string, password: string, nickname: string): Promise<void> {
    await AuthApi.register({
      username: username,
      password: password,
      nickname: nickname.length > 0 ? nickname : undefined
    });
  }

  static applyLogin(resp: LoginResp): void {
    AppStorage.setOrCreate('fg_token', resp.token);
    AppStorage.setOrCreate('fg_userId', resp.userId);
    AppStorage.setOrCreate('fg_nickname', resp.nickname ?? '');
    AppStorage.setOrCreate('fg_isAdmin', resp.isAdmin === true);
  }

  static async fetchProfile(silent: boolean = false): Promise<void> {
    const profile: UserProfile = await UserApi.profile(silent);
    AppStorage.setOrCreate('fg_userId', profile.userId);
    AppStorage.setOrCreate('fg_nickname', profile.nickname ?? '');
    AppStorage.setOrCreate('fg_location', profile.location ?? '');
  }

  static async logout(): Promise<void> {
    try {
      await AuthApi.logout();
    } catch (err) {
      console.warn(`logout request failed: ${JSON.stringify(err)}`);
    } finally {
      UserStore.clear();
    }
  }

  static clear(): void {
    AppStorage.setOrCreate('fg_token', '');
    AppStorage.setOrCreate('fg_userId', 0);
    AppStorage.setOrCreate('fg_nickname', '');
    AppStorage.setOrCreate('fg_isAdmin', false);
    AppStorage.setOrCreate('fg_location', '');
    PetStore.reset();
  }
}
