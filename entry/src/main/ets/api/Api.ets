import {
  AdminUser,
  AdminUserDetail,
  AiQueryResp,
  ChatMessage,
  ChatSession,
  CursorPage,
  ExchangePayload,
  FeedingLog,
  Food,
  FoodForm,
  FoodListParams,
  FoodNutrients,
  GeoAddress,
  KnowledgeDoc,
  LoginParams,
  LoginResp,
  MailSettings,
  NearbyPlace,
  NutritionPlan,
  NutritionRecipe,
  PageResult,
  Pet,
  PetForm,
  PlaceCategory,
  RegisterParams,
  Reminder,
  ReminderForm,
  ReminderLog,
  ReportConclusion,
  Tip,
  UserProfile,
  WalkRoute,
  WeatherToday,
  WeeklyReport,
  WeightForm,
  WeightLog
} from '../models/Types';
import { apiUpload, del, get, Params, post, put } from '../utils/Http';

export class AuthApi {
  static register(data: RegisterParams): Promise<number> {
    return post<number>('/api/auth/register', data);
  }

  static login(data: LoginParams): Promise<LoginResp> {
    return post<LoginResp>('/api/auth/login', data, true);
  }

  static logout(): Promise<void> {
    return post<Object>('/api/auth/logout').then(() => {
    });
  }
}

export class UserApi {
  static profile(silent: boolean = false): Promise<UserProfile> {
    return get<UserProfile>('/api/user/profile', silent);
  }

  static update(data: ProfileUpdate): Promise<UserProfile> {
    return put<UserProfile>('/api/user/profile', data);
  }

  static mailSettings(): Promise<MailSettings> {
    return get<MailSettings>('/api/user/mail-settings');
  }

  static updateMailSettings(data: MailSettings): Promise<MailSettings> {
    return put<MailSettings>('/api/user/mail-settings', data);
  }
}

export interface ProfileUpdate {
  nickname?: string;
  location?: string;
}

export class PetApi {
  static create(data: PetForm): Promise<number> {
    return post<number>('/api/pet', data);
  }

  static list(): Promise<Pet[]> {
    return get<Pet[]>('/api/pet/list');
  }

  static detail(id: number): Promise<Pet> {
    return get<Pet>(`/api/pet/${id}`);
  }

  static update(id: number, data: PetForm): Promise<void> {
    return put<Object>(`/api/pet/${id}`, data).then(() => {
    });
  }

  static remove(id: number): Promise<void> {
    return del<Object>(`/api/pet/${id}`).then(() => {
    });
  }

  static addWeight(id: number, data: WeightForm): Promise<void> {
    return post<Object>(`/api/pet/${id}/weight`, data).then(() => {
    });
  }

  static weightHistory(id: number): Promise<WeightLog[]> {
    return get<WeightLog[]>(`/api/pet/${id}/weight-history`);
  }
}

export class ReminderApi {
  static create(data: ReminderForm): Promise<number> {
    return post<number>('/api/reminder', data);
  }

  static list(petId?: number, silent: boolean = false): Promise<Reminder[]> {
    const params: Params = new Params();
    params.add('petId', petId);
    return get<Reminder[]>(`/api/reminder/list${params.build()}`, silent);
  }

  static update(id: number, data: ReminderForm): Promise<void> {
    return put<Object>(`/api/reminder/${id}`, data).then(() => {
    });
  }

  static remove(id: number): Promise<void> {
    return del<Object>(`/api/reminder/${id}`).then(() => {
    });
  }

  static checkin(id: number, data: CheckinBody): Promise<void> {
    return post<Object>(`/api/reminder/${id}/checkin`, data).then(() => {
    });
  }

  static logs(petId: number, startDate?: string, endDate?: string, silent: boolean = false): Promise<ReminderLog[]> {
    const params: Params = new Params();
    params.add('petId', petId).add('startDate', startDate).add('endDate', endDate);
    return get<ReminderLog[]>(`/api/reminder/logs${params.build()}`, silent);
  }
}

export interface CheckinBody {
  doneDate?: string;
  note?: string;
}

export class FoodApi {
  static create(data: FoodForm): Promise<number> {
    return post<number>('/api/food', data);
  }

  static list(params: FoodListParams): Promise<PageResult<Food>> {
    const query: Params = new Params();
    query.add('page', params.page).add('size', params.size).add('keyword', params.keyword);
    return get<PageResult<Food>>(`/api/food/list${query.build()}`);
  }

  static detail(id: number): Promise<Food> {
    return get<Food>(`/api/food/${id}`);
  }

  static update(id: number, data: FoodForm): Promise<void> {
    return put<Object>(`/api/food/${id}`, data).then(() => {
    });
  }

  static remove(id: number): Promise<void> {
    return del<Object>(`/api/food/${id}`).then(() => {
    });
  }

  static nutrients(id: number): Promise<FoodNutrients> {
    return get<FoodNutrients>(`/api/food/${id}/nutrients`);
  }
}

export class NutritionApi {
  static calculate(petId: number, foodId: number): Promise<NutritionPlan> {
    const params: Params = new Params();
    params.add('petId', petId).add('foodId', foodId);
    return get<NutritionPlan>(`/api/nutrition/calculate${params.build()}`);
  }

  static recipe(petId: number, foodId: number): Promise<NutritionRecipe> {
    const params: Params = new Params();
    params.add('petId', petId).add('foodId', foodId);
    return get<NutritionRecipe>(`/api/nutrition/recipe${params.build()}`);
  }
}

export class ReportApi {
  static generate(petId: number, weekStart: string): Promise<WeeklyReport> {
    const params: Params = new Params();
    params.add('petId', petId).add('weekStart', weekStart);
    return post<WeeklyReport>(`/api/report/generate${params.build()}`);
  }

  static list(petId: number): Promise<WeeklyReport[]> {
    const params: Params = new Params();
    params.add('petId', petId);
    return get<WeeklyReport[]>(`/api/report/list${params.build()}`);
  }

  static detail(id: number): Promise<WeeklyReport> {
    return get<WeeklyReport>(`/api/report/${id}`);
  }

  static conclusions(id: number): Promise<ReportConclusion> {
    return get<ReportConclusion>(`/api/report/${id}/conclusions`);
  }

  static polish(id: number, force: boolean = false): Promise<WeeklyReport> {
    const params: Params = new Params();
    params.add('force', force);
    return post<WeeklyReport>(`/api/report/${id}/polish${params.build()}`);
  }

  static summary(id: number): Promise<string> {
    return get<string>(`/api/report/${id}/summary`);
  }
}

export class KnowledgeApi {
  static sessions(cursor?: string, limit?: number): Promise<CursorPage<ChatSession>> {
    const params: Params = new Params();
    params.add('cursor', cursor).add('limit', limit);
    return get<CursorPage<ChatSession>>(`/api/knowledge/chats${params.build()}`);
  }

  static createChat(title?: string, petId?: number): Promise<ChatSession> {
    const body: CreateChatBody = {};
    if (title) {
      body.title = title;
    }
    if (petId) {
      body.petId = petId;
    }
    return post<ChatSession>('/api/knowledge/chats', body);
  }

  static rename(id: number, title: string): Promise<void> {
    const body: RenameBody = { title: title };
    return put<Object>(`/api/knowledge/chats/${id}`, body).then(() => {
    });
  }

  static remove(id: number): Promise<void> {
    return del<Object>(`/api/knowledge/chats/${id}`).then(() => {
    });
  }

  static messages(id: number, cursor?: string, limit?: number): Promise<CursorPage<ChatMessage>> {
    const params: Params = new Params();
    params.add('cursor', cursor).add('limit', limit);
    return get<CursorPage<ChatMessage>>(`/api/knowledge/chats/${id}/messages${params.build()}`);
  }

  static append(id: number, data: ExchangePayload): Promise<void> {
    return post<Object>(`/api/knowledge/chats/${id}/messages`, data).then(() => {
    });
  }
}

export interface CreateChatBody {
  title?: string;
  petId?: number;
}

export interface RenameBody {
  title: string;
}

export class AiApi {
  static query(query: string, petId?: number): Promise<AiQueryResp> {
    const body: AiQueryBody = { query: query };
    if (petId) {
      body.petId = petId;
    }
    return post<AiQueryResp>('/api/ai/query', body);
  }

  static search(query: string, species?: string, lifeStage?: string, topN?: number): Promise<KnowledgeDoc[]> {
    const params: Params = new Params();
    params.add('query', query).add('species', species).add('lifeStage', lifeStage).add('topN', topN);
    return get<KnowledgeDoc[]>(`/api/ai/search${params.build()}`);
  }
}

export interface AiQueryBody {
  query: string;
  petId?: number;
}

export class TipApi {
  static today(petId: number, mock: boolean = false): Promise<Tip> {
    const params: Params = new Params();
    params.add('petId', petId).add('mock', mock);
    return get<Tip>(`/api/tip/today${params.build()}`);
  }

  static history(petId: number, limit: number = 10): Promise<Tip[]> {
    const params: Params = new Params();
    params.add('petId', petId).add('limit', limit);
    return get<Tip[]>(`/api/tip/history${params.build()}`);
  }

  static feedback(tipId: number, feedback: string): Promise<void> {
    const body: FeedbackBody = { feedback: feedback };
    return post<Object>(`/api/tip/${tipId}/feedback`, body).then(() => {
    });
  }

  static checkRedline(text: string): Promise<boolean> {
    const params: Params = new Params();
    params.add('text', text);
    return post<boolean>(`/api/tip/check-redline${params.build()}`);
  }

  static streamPath(petId: number, mock: boolean = false, refresh: boolean = false): string {
    return `/api/tip/stream?petId=${petId}&mock=${mock}&refresh=${refresh}`;
  }
}

export interface FeedbackBody {
  feedback: string;
}

export class WeatherApi {
  static today(lat?: number, lng?: number): Promise<WeatherToday | null> {
    const params: Params = new Params();
    params.add('lat', lat).add('lng', lng);
    return get<WeatherToday | null>(`/api/weather/today${params.build()}`, true);
  }
}

export class PlacesApi {
  static nearby(lat: number, lng: number, category: PlaceCategory, radius: number): Promise<NearbyPlace[]> {
    const params: Params = new Params();
    params.add('lat', lat).add('lng', lng).add('category', category).add('radius', radius);
    return get<NearbyPlace[]>(`/api/places/nearby${params.build()}`);
  }

  static walk(fromLat: number, fromLng: number, toLat: number, toLng: number): Promise<WalkRoute> {
    const params: Params = new Params();
    params.add('fromLat', fromLat).add('fromLng', fromLng).add('toLat', toLat).add('toLng', toLng);
    return get<WalkRoute>(`/api/places/walk${params.build()}`);
  }

  static regeo(lat: number, lng: number): Promise<GeoAddress> {
    const params: Params = new Params();
    params.add('lat', lat).add('lng', lng);
    return get<GeoAddress>(`/api/places/regeo${params.build()}`, true);
  }
}

export class FeedingApi {
  static create(data: FeedingCreateBody): Promise<number> {
    return post<number>('/api/feeding', data);
  }

  static list(petId?: number, startDate?: string, endDate?: string): Promise<FeedingLog[]> {
    const params: Params = new Params();
    params.add('petId', petId).add('startDate', startDate).add('endDate', endDate);
    return get<FeedingLog[]>(`/api/feeding/list${params.build()}`);
  }
}

export interface FeedingCreateBody {
  petId: number;
  foodId: number;
  grams: number;
  fedDate?: string;
  mealIndex?: number;
}

export class AdminApi {
  static listUsers(page: number = 1, size: number = 20, keyword?: string): Promise<PageResult<AdminUser>> {
    const params: Params = new Params();
    params.add('page', page).add('size', size).add('keyword', keyword);
    return get<PageResult<AdminUser>>(`/api/admin/users${params.build()}`);
  }

  static getUser(id: number): Promise<AdminUserDetail> {
    return get<AdminUserDetail>(`/api/admin/users/${id}`);
  }

  static updateStatus(id: number, status: number): Promise<void> {
    const body: StatusBody = { status: status };
    return put<Object>(`/api/admin/users/${id}/status`, body).then(() => {
    });
  }
}

export interface StatusBody {
  status: number;
}

export interface AvatarUploadResult {
  url: string;
}

export class UploadApi {
  static avatar(data: ArrayBuffer, fileName: string, contentType: string): Promise<AvatarUploadResult> {
    return apiUpload<AvatarUploadResult>('/api/upload/avatar', data, fileName, contentType);
  }
}
