export interface ApiResult<T> {
  code: number;
  message: string;
  data: T;
  timestamp: number;
}

export interface PageResult<T> {
  records: T[];
  total: number;
  size: number;
  current: number;
  pages: number;
}

export interface CursorPage<T> {
  records: T[];
  nextCursor: string | null;
  hasMore: boolean;
}

export type Species = 'dog' | 'cat';
export type Sex = 'male' | 'female';
export type ActivityLevel = 'SEDENTARY' | 'LOW' | 'MODERATE' | 'HIGH' | 'WORKING';
export type Physiology = 'NORMAL' | 'PREGNANT' | 'LACTATING';
export type FoodType = 'DRY' | 'WET' | 'FREEZE_DRIED' | 'SNACK' | 'CANNED';
export type ProductType = 'COMPLETE' | 'COMPLEMENTARY' | 'SNACK';
export type LifeStage = 'ALL' | 'BABY' | 'ADULT' | 'SENIOR';
export type SpeciesScope = 'DOG' | 'CAT' | 'BOTH';
export type ReminderType = 'FEED' | 'WALK' | 'WATER' | 'GROOMING' | 'DEWORM' | 'VACCINE' | 'BATH' | 'CUSTOM';
export type RepeatRule = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY' | 'ONCE';
export type PlaceCategory = 'medical' | 'park';

export interface LoginParams {
  username: string;
  password: string;
}

export interface RegisterParams {
  username: string;
  password: string;
  nickname?: string;
}

export interface LoginResp {
  token: string;
  userId: number;
  nickname: string;
  isAdmin: boolean;
}

export interface UserProfile {
  userId: number;
  username: string;
  nickname?: string;
  location?: string;
}

export interface MailSettings {
  email: string;
  enabled: boolean;
}

export interface GeoAddress {
  province?: string;
  city?: string;
  district?: string;
  label: string;
}

export interface AdminUser {
  id: number;
  username: string;
  nickname?: string;
  avatar?: string;
  status: number;
  isAdmin: boolean;
  petCount: number;
  createdAt?: string;
}

export interface AdminPet {
  id: number;
  name: string;
  species: Species;
  breed?: string;
  sex?: Sex;
  birthday?: string;
  avatar?: string;
  createdAt?: string;
}

export interface AdminUserDetail {
  id: number;
  username: string;
  nickname?: string;
  avatar?: string;
  status: number;
  isAdmin: boolean;
  createdAt?: string;
  updatedAt?: string;
  pets: AdminPet[];
}

export interface Pet {
  id: number;
  name: string;
  species: Species;
  breed?: string;
  sex: Sex;
  neutered: number | boolean;
  birthday?: string;
  activityLevel?: ActivityLevel;
  bcs?: number;
  physiology?: Physiology;
  avatar?: string | null;
  createdAt?: string;
  updatedAt?: string;
}

export interface PetForm {
  name: string;
  species: Species;
  breed?: string;
  avatar?: string;
  sex: Sex;
  neutered?: boolean;
  birthday?: string;
  activityLevel?: ActivityLevel;
  bcs?: number;
  physiology?: Physiology;
}

export interface WeightLog {
  id: number;
  petId: number;
  weightKg: number;
  bcs?: number;
  recordedAt: string;
  createdAt?: string;
}

export interface WeightForm {
  weightKg?: number;
  bcs?: number;
  recordedAt?: string;
}

export interface FoodNutrients {
  moistureMax?: number;
  crudeProteinMin?: number;
  crudeFatMin?: number;
  crudeFiberMax?: number;
  ashMax?: number;
  calciumMin?: number;
  phosphorusMin?: number;
  taurineMin?: number;
  lysineMin?: number;
}

export interface Food {
  id: number;
  name: string;
  userId?: number | null;
  brand?: string;
  foodType?: FoodType;
  productType?: ProductType;
  lifeStage?: LifeStage;
  speciesScope?: SpeciesScope;
  labeledMeKcal?: number;
  ingredients?: string;
  nutrients?: FoodNutrients;
  createdAt?: string;
  updatedAt?: string;
}

export interface FoodForm {
  name: string;
  brand?: string;
  foodType?: FoodType;
  productType?: ProductType;
  lifeStage?: LifeStage;
  speciesScope?: SpeciesScope;
  labeledMeKcal?: number;
  ingredients?: string;
  nutrients?: FoodNutrients;
}

export interface FoodListParams {
  page?: number;
  size?: number;
  keyword?: string;
}

export interface NutrientValidation {
  nutrient: string;
  actualValue: number;
  requiredMin?: number;
  requiredMax?: number;
  passed: boolean;
  unit: string;
}

export interface NutritionPlan {
  rerKcal: number;
  merKcal: number;
  mainFoodGrams: number;
  snackBudgetKcal: number;
  snackBudgetGrams: number;
  mealsPerDay: number;
  gramsPerMeal: number;
  energyDensityKcalPer100g: number;
  energyEstimated: boolean;
  calculationProcess: string;
  idealWeightUsed?: number | null;
  overweight: boolean;
  underweight: boolean;
  weightAdvice?: string | null;
  validations: NutrientValidation[];
  warnings?: string[];
}

export interface RecipeSource {
  docId: number;
  title: string;
  sourceName?: string;
}

export interface RecipeSnack {
  id: number;
  name: string;
  brand?: string;
  labeledMeKcal?: number;
  maxGrams?: number;
}

export interface NutritionRecipe {
  content: string;
  sources: RecipeSource[];
  snacks: RecipeSnack[];
  isFallback: boolean;
}

export interface WeatherToday {
  location: string;
  text: string;
  textNight?: string;
  high: number;
  low: number;
  windDirection?: string;
  windScale?: string;
  humidity?: string;
  precip?: number;
  level: 'GOOD' | 'CAUTION' | 'AVOID';
  advice: string;
}

export interface Reminder {
  id: number;
  petId: number;
  title: string;
  reminderType: ReminderType;
  remindTime?: string;
  relativeMin?: number;
  remindDate?: string;
  repeatRule?: RepeatRule;
  repeatDays?: string;
  createdAt?: string;
}

export interface ReminderForm {
  petId: number;
  title: string;
  reminderType: ReminderType;
  remindTime?: string;
  relativeMin?: number;
  remindDate?: string;
  repeatRule?: RepeatRule;
  repeatDays?: string;
}

export interface ReminderLog {
  id: number;
  reminderId: number;
  petId: number;
  doneDate: string;
  note?: string;
  createdAt?: string;
}

export interface FeedingLog {
  id: number;
  petId: number;
  foodId: number;
  fedDate: string;
  mealIndex: number;
  grams: number;
  kcal?: number | null;
  createdAt?: string;
}

export interface Tip {
  id: number;
  petId: number;
  tipDate: string;
  content: string;
  sourceDocId?: number;
  sourceName?: string;
  feedback?: number | null;
  isMock: number;
  createdAt?: string;
}

export interface ReportRule {
  ruleId: string;
  ruleName: string;
  triggered: boolean;
  severity: 'info' | 'warn' | 'danger';
  suggestion: string;
  detail: string;
}

export interface ReportConclusion {
  rules: ReportRule[];
  summary: string;
}

export interface WeeklyReport {
  id: number;
  petId: number;
  weekStart: string;
  weekEnd: string;
  weightStartKg?: number;
  weightEndKg?: number;
  weightChangePct?: number;
  bcsStart?: number;
  bcsEnd?: number;
  feedingCompliance?: number;
  snackOverLimit?: number;
  ruleConclusions?: string;
  llmSummary?: string | null;
  status: string;
  createdAt?: string;
}

export interface AiSource {
  docId: number;
  title: string;
  sourceName: string;
}

export interface AiQueryResp {
  content: string;
  sources: AiSource[];
  isFallback: boolean;
}

export interface KnowledgeDoc {
  id: number;
  title: string;
  content?: string;
  species?: string;
  lifeStage?: string;
  topics?: string;
  severity?: 'informational' | 'caution' | 'emergency';
  sourceName?: string;
  sourceUrl?: string;
  updatedAt?: string;
}

export interface ChatSource {
  docId: number;
  title: string;
  sourceName: string;
  sourceType?: string;
  severity?: string;
}

export interface ChatMessage {
  id: number;
  role: 'user' | 'ai';
  content: string;
  sources: ChatSource[];
  isRedLine: boolean;
  isFallback: boolean;
  createdAt: string;
}

export interface ChatSession {
  id: number;
  title: string;
  petId?: number | null;
  messageCount: number;
  sourceCount: number;
  createdAt: string;
  updatedAt: string;
}

export interface ExchangePayload {
  question: string;
  answer: string;
  sourceDocIds: number[];
  isRedLine: boolean;
  isFallback: boolean;
}

export interface NearbyPlace {
  id: string;
  name: string;
  type: string;
  address?: string | null;
  tel?: string | null;
  lat: number;
  lng: number;
  distanceMeters: number;
}

export interface WalkRoute {
  distanceMeters: number;
  durationSeconds: number;
  polyline: number[][];
}

export class NearbyNavParam {
  reminderId: number = 0;
  reminderTitle: string = '';
  petId: number = 0;
  category: PlaceCategory = 'medical';

  constructor(reminderId: number, reminderTitle: string, petId: number, category: PlaceCategory) {
    this.reminderId = reminderId;
    this.reminderTitle = reminderTitle;
    this.petId = petId;
    this.category = category;
  }
}

export interface SelectOption {
  value: string;
  label: string;
}

export interface PetAvatarOption {
  key: string;
  species: Species;
  resource: string;
}
