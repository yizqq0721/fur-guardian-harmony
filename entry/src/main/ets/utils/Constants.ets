import { ActivityLevel, FoodType, LifeStage, Physiology, ProductType, ReminderType, RepeatRule, SelectOption, SpeciesScope } from '../models/Types';

export const ACTIVITY_OPTIONS: SelectOption[] = [
  { value: 'SEDENTARY', label: '久坐（几乎不运动）' },
  { value: 'LOW', label: '低（偶尔散步）' },
  { value: 'MODERATE', label: '中（每日规律活动）' },
  { value: 'HIGH', label: '高（大量运动）' },
  { value: 'WORKING', label: '工作犬' },
];

export const PHYSIOLOGY_OPTIONS: SelectOption[] = [
  { value: 'NORMAL', label: '正常' },
  { value: 'PREGNANT', label: '妊娠期' },
  { value: 'LACTATING', label: '哺乳期' },
];

export const FOOD_TYPE_OPTIONS: SelectOption[] = [
  { value: 'DRY', label: '干粮' },
  { value: 'WET', label: '湿粮' },
  { value: 'FREEZE_DRIED', label: '冻干' },
  { value: 'SNACK', label: '零食' },
  { value: 'CANNED', label: '罐头' },
];

export const PRODUCT_TYPE_OPTIONS: SelectOption[] = [
  { value: 'COMPLETE', label: '全价粮（可作唯一主食）' },
  { value: 'COMPLEMENTARY', label: '补充粮（不可作唯一主食）' },
  { value: 'SNACK', label: '零食' },
];

export const LIFE_STAGE_OPTIONS: SelectOption[] = [
  { value: 'ALL', label: '全阶段' },
  { value: 'BABY', label: '幼年' },
  { value: 'ADULT', label: '成年' },
  { value: 'SENIOR', label: '老年' },
];

export const SPECIES_SCOPE_OPTIONS: SelectOption[] = [
  { value: 'DOG', label: '犬用' },
  { value: 'CAT', label: '猫用' },
  { value: 'BOTH', label: '犬猫通用' },
];

export const REMINDER_TYPE_OPTIONS: SelectOption[] = [
  { value: 'FEED', label: '喂食' },
  { value: 'WALK', label: '遛弯' },
  { value: 'WATER', label: '喂水/换水' },
  { value: 'GROOMING', label: '梳毛' },
  { value: 'DEWORM', label: '驱虫' },
  { value: 'VACCINE', label: '疫苗' },
  { value: 'BATH', label: '洗澡' },
  { value: 'CUSTOM', label: '自定义' },
];

export const REPEAT_RULE_OPTIONS: SelectOption[] = [
  { value: 'DAILY', label: '每天' },
  { value: 'WEEKLY', label: '每周' },
  { value: 'MONTHLY', label: '每月' },
  { value: 'YEARLY', label: '每年' },
  { value: 'ONCE', label: '仅一次' },
];

function labelOf(options: SelectOption[], value?: string | null): string {
  if (!value) {
    return '';
  }
  const found: SelectOption | undefined = options.find((item: SelectOption) => item.value === value);
  return found ? found.label : value;
}

export function foodTypeLabel(value?: FoodType): string {
  return labelOf(FOOD_TYPE_OPTIONS, value);
}

export function productTypeLabel(value?: ProductType): string {
  return labelOf(PRODUCT_TYPE_OPTIONS, value);
}

export function lifeStageLabel(value?: LifeStage): string {
  return labelOf(LIFE_STAGE_OPTIONS, value);
}

export function speciesScopeLabel(value?: SpeciesScope): string {
  return labelOf(SPECIES_SCOPE_OPTIONS, value);
}

export function reminderTypeLabel(value?: ReminderType): string {
  return labelOf(REMINDER_TYPE_OPTIONS, value);
}

export function repeatRuleLabel(value?: RepeatRule | null): string {
  return labelOf(REPEAT_RULE_OPTIONS, value);
}

export function activityLabel(value?: ActivityLevel): string {
  return labelOf(ACTIVITY_OPTIONS, value);
}

export function physiologyLabel(value?: Physiology): string {
  return labelOf(PHYSIOLOGY_OPTIONS, value);
}

export class BcsGroup {
  min: number = 1;
  max: number = 9;
  label: string = '';
  desc: string = '';
  color: string = '';

  constructor(min: number, max: number, label: string, desc: string, color: string) {
    this.min = min;
    this.max = max;
    this.label = label;
    this.desc = desc;
    this.color = color;
  }
}

/** BCS 1-9 分制描述；配色：理想=accent，偏瘦/偏重=warning，肥胖=danger */
export const BCS_GROUPS: BcsGroup[] = [
  new BcsGroup(1, 3, '偏瘦', '肋骨、腰椎明显可见，缺乏体脂覆盖', '#B45309'),
  new BcsGroup(4, 5, '理想', '肋骨可触及但不明显，腰部线条清晰', '#1F5C4A'),
  new BcsGroup(6, 7, '偏重', '肋骨较难触及，腰部线条不明显', '#B45309'),
  new BcsGroup(8, 9, '肥胖', '肋骨无法触及，腹部明显下垂', '#B42318'),
];

export function bcsGroup(bcs: number): BcsGroup {
  const found: BcsGroup | undefined = BCS_GROUPS.find((g: BcsGroup) => bcs >= g.min && bcs <= g.max);
  return found ?? BCS_GROUPS[1];
}

export function speciesLabel(species?: string): string {
  return species === 'cat' ? '猫' : '犬';
}

export function speciesFullLabel(species?: string): string {
  return species === 'cat' ? '猫咪' : '狗狗';
}
