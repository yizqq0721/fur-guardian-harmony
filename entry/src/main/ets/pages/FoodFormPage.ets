import { FoodApi } from '../api/Api';
import { FG } from '../common/Theme';
import { FgButton } from '../components/FgButton';
import { FgInput } from '../components/FgInput';
import { FgSelect } from '../components/FgSelect';
import { PageHeader } from '../components/PageHeader';
import { Food, FoodForm, FoodNutrients, FoodType, LifeStage, ProductType, SpeciesScope } from '../models/Types';
import {
  FOOD_TYPE_OPTIONS,
  LIFE_STAGE_OPTIONS,
  PRODUCT_TYPE_OPTIONS,
  SPECIES_SCOPE_OPTIONS
} from '../utils/Constants';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';

class NutrientSpec {
  key: string;
  label: string;

  constructor(key: string, label: string) {
    this.key = key;
    this.label = label;
  }
}

class NutrientTexts {
  moistureMax: string = '';
  crudeProteinMin: string = '';
  crudeFatMin: string = '';
  crudeFiberMax: string = '';
  ashMax: string = '';
  calciumMin: string = '';
  phosphorusMin: string = '';
  taurineMin: string = '';
  lysineMin: string = '';
}

const NUTRIENT_SPECS: NutrientSpec[] = [
  new NutrientSpec('moistureMax', '水分 ≤'),
  new NutrientSpec('crudeProteinMin', '粗蛋白质 ≥'),
  new NutrientSpec('crudeFatMin', '粗脂肪 ≥'),
  new NutrientSpec('crudeFiberMax', '粗纤维 ≤'),
  new NutrientSpec('ashMax', '粗灰分 ≤'),
  new NutrientSpec('calciumMin', '钙 ≥'),
  new NutrientSpec('phosphorusMin', '总磷 ≥'),
  new NutrientSpec('taurineMin', '牛磺酸 ≥（猫粮）'),
  new NutrientSpec('lysineMin', '赖氨酸 ≥（犬粮）')
];

function parseNumber(text: string): number | undefined {
  const trimmed: string = text.trim();
  if (trimmed.length === 0) {
    return undefined;
  }
  const value: number = Number(trimmed);
  return isNaN(value) ? undefined : value;
}

function numText(value?: number): string {
  return value === undefined || value === null ? '' : `${value}`;
}

function setNutrientValue(target: FoodNutrients, key: string, value: number): void {
  if (key === 'moistureMax') {
    target.moistureMax = value;
  } else if (key === 'crudeProteinMin') {
    target.crudeProteinMin = value;
  } else if (key === 'crudeFatMin') {
    target.crudeFatMin = value;
  } else if (key === 'crudeFiberMax') {
    target.crudeFiberMax = value;
  } else if (key === 'ashMax') {
    target.ashMax = value;
  } else if (key === 'calciumMin') {
    target.calciumMin = value;
  } else if (key === 'phosphorusMin') {
    target.phosphorusMin = value;
  } else if (key === 'taurineMin') {
    target.taurineMin = value;
  } else if (key === 'lysineMin') {
    target.lysineMin = value;
  }
}

/** 与 Vue FoodFormView 一致：基本信息 + 保证分析值（含 DM 预览）+ 能量 */
@Component
export struct FoodFormPage {
  @Prop editId: number = 0;
  @State private loading: boolean = false;
  @State private loadError: string = '';
  @State private saving: boolean = false;
  @State private name: string = '';
  @State private brand: string = '';
  @State private foodType: FoodType = 'DRY';
  @State private productType: ProductType = 'COMPLETE';
  @State private lifeStage: LifeStage = 'ADULT';
  @State private speciesScope: SpeciesScope = 'DOG';
  @State private ingredients: string = '';
  @State private kcalText: string = '';
  @State private nutrientTexts: NutrientTexts = new NutrientTexts();

  aboutToAppear(): void {
    if (this.editId > 0) {
      this.loadDetail();
    }
  }

  private isEdit(): boolean {
    return this.editId > 0;
  }

  private async loadDetail(): Promise<void> {
    this.loading = true;
    this.loadError = '';
    try {
      const food: Food = await FoodApi.detail(this.editId);
      this.name = food.name;
      this.brand = food.brand ?? '';
      this.foodType = food.foodType ?? 'DRY';
      this.productType = food.productType ?? 'COMPLETE';
      this.lifeStage = food.lifeStage ?? 'ADULT';
      this.speciesScope = food.speciesScope ?? 'DOG';
      this.kcalText = numText(food.labeledMeKcal);
      this.ingredients = food.ingredients ?? '';
      let nutrients: FoodNutrients | undefined = undefined;
      try {
        nutrients = await FoodApi.nutrients(this.editId);
      } catch (err) {
        nutrients = food.nutrients;
      }
      this.applyNutrients(nutrients);
    } catch (err) {
      console.error(`load food failed: ${JSON.stringify(err)}`);
      this.loadError = '食品信息加载失败，请返回后重试';
    } finally {
      this.loading = false;
    }
  }

  private applyNutrients(nutrients?: FoodNutrients): void {
    if (nutrients === undefined || nutrients === null) {
      return;
    }
    this.nutrientTexts.moistureMax = numText(nutrients.moistureMax);
    this.nutrientTexts.crudeProteinMin = numText(nutrients.crudeProteinMin);
    this.nutrientTexts.crudeFatMin = numText(nutrients.crudeFatMin);
    this.nutrientTexts.crudeFiberMax = numText(nutrients.crudeFiberMax);
    this.nutrientTexts.ashMax = numText(nutrients.ashMax);
    this.nutrientTexts.calciumMin = numText(nutrients.calciumMin);
    this.nutrientTexts.phosphorusMin = numText(nutrients.phosphorusMin);
    this.nutrientTexts.taurineMin = numText(nutrients.taurineMin);
    this.nutrientTexts.lysineMin = numText(nutrients.lysineMin);
  }

  private nutrientValue(key: string): string {
    if (key === 'moistureMax') {
      return this.nutrientTexts.moistureMax;
    }
    if (key === 'crudeProteinMin') {
      return this.nutrientTexts.crudeProteinMin;
    }
    if (key === 'crudeFatMin') {
      return this.nutrientTexts.crudeFatMin;
    }
    if (key === 'crudeFiberMax') {
      return this.nutrientTexts.crudeFiberMax;
    }
    if (key === 'ashMax') {
      return this.nutrientTexts.ashMax;
    }
    if (key === 'calciumMin') {
      return this.nutrientTexts.calciumMin;
    }
    if (key === 'phosphorusMin') {
      return this.nutrientTexts.phosphorusMin;
    }
    if (key === 'taurineMin') {
      return this.nutrientTexts.taurineMin;
    }
    if (key === 'lysineMin') {
      return this.nutrientTexts.lysineMin;
    }
    return '';
  }

  private setNutrient(key: string, value: string): void {
    if (key === 'moistureMax') {
      this.nutrientTexts.moistureMax = value;
    } else if (key === 'crudeProteinMin') {
      this.nutrientTexts.crudeProteinMin = value;
    } else if (key === 'crudeFatMin') {
      this.nutrientTexts.crudeFatMin = value;
    } else if (key === 'crudeFiberMax') {
      this.nutrientTexts.crudeFiberMax = value;
    } else if (key === 'ashMax') {
      this.nutrientTexts.ashMax = value;
    } else if (key === 'calciumMin') {
      this.nutrientTexts.calciumMin = value;
    } else if (key === 'phosphorusMin') {
      this.nutrientTexts.phosphorusMin = value;
    } else if (key === 'taurineMin') {
      this.nutrientTexts.taurineMin = value;
    } else if (key === 'lysineMin') {
      this.nutrientTexts.lysineMin = value;
    }
  }

  private dmBase(): number | undefined {
    const moisture: number | undefined = parseNumber(this.nutrientTexts.moistureMax);
    if (moisture === undefined || moisture >= 100) {
      return undefined;
    }
    return 100 - moisture;
  }

  private moistureText(): string {
    const moisture: number | undefined = parseNumber(this.nutrientTexts.moistureMax);
    return moisture === undefined ? '—' : moisture.toFixed(1);
  }

  private dmOf(key: string): string {
    const base: number | undefined = this.dmBase();
    const value: number | undefined = parseNumber(this.nutrientValue(key));
    if (base === undefined || value === undefined) {
      return '—';
    }
    return ((value / base) * 100).toFixed(1);
  }

  private async save(): Promise<void> {
    if (this.saving) {
      return;
    }
    const name: string = this.name.trim();
    if (name.length === 0) {
      showToast('请填写食品名称');
      return;
    }

    const nutrients: FoodNutrients = {};
    let hasNutrients: boolean = false;
    for (let i = 0; i < NUTRIENT_SPECS.length; i++) {
      const spec: NutrientSpec = NUTRIENT_SPECS[i];
      const value: number | undefined = parseNumber(this.nutrientValue(spec.key));
      if (value === undefined) {
        continue;
      }
      if (value < 0 || value > 100) {
        showToast(`「${spec.label}」需在 0-100 之间`);
        return;
      }
      setNutrientValue(nutrients, spec.key, value);
      hasNutrients = true;
    }

    let kcal: number | undefined = parseNumber(this.kcalText);    if (kcal !== undefined && (kcal < 0 || kcal > 6000)) {
      showToast('代谢能需在 0-6000 kcal/kg 之间');
      return;
    }

    const payload: FoodForm = {
      name: name,
      foodType: this.foodType,
      productType: this.productType,
      lifeStage: this.lifeStage,
      speciesScope: this.speciesScope
    };
    const brand: string = this.brand.trim();
    if (brand.length > 0) {
      payload.brand = brand;
    }
    const ingredients: string = this.ingredients.trim();
    if (ingredients.length > 0) {
      payload.ingredients = ingredients;
    }
    if (kcal !== undefined) {
      payload.labeledMeKcal = kcal;
    }
    if (hasNutrients) {
      payload.nutrients = nutrients;
    }

    this.saving = true;
    try {
      if (this.isEdit()) {
        await FoodApi.update(this.editId, payload);
        showToast('已保存');
      } else {
        await FoodApi.create(payload);
        showToast('录入成功');
      }
      AppStorage.setOrCreate('fg_foodsDirty', true);
      Nav.pop();
    } catch (err) {
      console.error(`save food failed: ${JSON.stringify(err)}`);
    } finally {
      this.saving = false;
    }
  }

  @Builder
  FieldLabel(label: string) {
    Text(label)
      .fontSize(FG.textLabel)
      .fontWeight(FontWeight.Medium)
      .letterSpacing(0.4)
      .fontColor(FG.inkMuted)
      .width('100%')
      .margin({ bottom: 6 })
  }

  @Builder
  NumberField(label: string, value: string, unit: string, onChange: (value: string) => void) {
    Column() {
      this.FieldLabel(label)
      Stack({ alignContent: Alignment.End }) {
        TextInput({ text: value, placeholder: '未标注' })
          .type(InputType.NUMBER_DECIMAL)
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontColor(FG.ink)
          .placeholderColor('#A3A6AC')
          .backgroundColor(FG.surface)
          .borderRadius(FG.radius)
          .border({ width: 1, color: FG.line })
          .padding({ left: 12, right: unit.length > 0 ? 38 : 12 })
          .onChange(onChange)
        if (unit.length > 0) {
          Text(unit)
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ right: 12 })
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 16 })
  }

  @Builder
  SectionDivider() {
    Divider()
      .color(FG.line)
      .strokeWidth(1)
      .margin({ top: 8, bottom: 20 })
  }

  @Builder
  BasicSection() {
    Column() {
      Text('基本信息')
        .fontFamily(FG.serif)
        .fontSize(FG.textH3)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .letterSpacing(-0.2)
        .width('100%')
        .margin({ bottom: 16 })

      FgInput({
        label: '食品名称',
        value: this.name,
        placeholder: '例如：皇家贵宾成犬粮',
        onChange: (value: string) => {
          this.name = value;
        }
      })
        .margin({ bottom: 16 })

      FgInput({
        label: '品牌',
        value: this.brand,
        placeholder: '例如：Royal Canin',
        onChange: (value: string) => {
          this.brand = value;
        }
      })
        .margin({ bottom: 16 })

      FgSelect({
        label: '类型',
        value: this.foodType,
        options: FOOD_TYPE_OPTIONS,
        onChange: (value: string) => {
          this.foodType = value as FoodType;
        }
      })
        .margin({ bottom: 16 })

      FgSelect({
        label: '产品类型',
        value: this.productType,
        options: PRODUCT_TYPE_OPTIONS,
        onChange: (value: string) => {
          this.productType = value as ProductType;
        }
      })
        .margin({ bottom: 16 })

      FgSelect({
        label: '适用阶段',
        value: this.lifeStage,
        options: LIFE_STAGE_OPTIONS,
        onChange: (value: string) => {
          this.lifeStage = value as LifeStage;
        }
      })
        .margin({ bottom: 16 })

      FgSelect({
        label: '物种范围',
        value: this.speciesScope,
        options: SPECIES_SCOPE_OPTIONS,
        onChange: (value: string) => {
          this.speciesScope = value as SpeciesScope;
        }
      })
        .margin({ bottom: 16 })

      FgInput({
        label: '原料组成',
        value: this.ingredients,
        placeholder: '按包装标注顺序，用逗号分隔',
        multiline: true,
        maxLength: 300,
        onChange: (value: string) => {
          this.ingredients = value;
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  AnalysisSection() {
    Column() {
      Text('产品成分分析保证值')
        .fontFamily(FG.serif)
        .fontSize(FG.textH3)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .letterSpacing(-0.2)
        .width('100%')
        .margin({ bottom: 16 })

      ForEach(NUTRIENT_SPECS, (spec: NutrientSpec) => {
        this.NumberField(spec.label, this.nutrientValue(spec.key), '%', (value: string) => {
          this.setNutrient(spec.key, value);
        })
      }, (spec: NutrientSpec) => `nutrient-${spec.key}`)

      Column() {
        Text('干物质基准 DM%')
          .fontSize(FG.textLabel)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(0.4)
          .fontColor(FG.inkMuted)
          .width('100%')
        if (this.dmBase() !== undefined) {
          Text(`DM ＝ 100 − 水分 ${this.moistureText()} ＝ ${(this.dmBase() as number).toFixed(1)}`)
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .lineHeight(20)
            .margin({ top: 8 })
            .width('100%')
          Row() {
            Text('粗蛋白')
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .layoutWeight(1)
            Text(`${this.dmOf('crudeProteinMin')} %`)
              .fontSize(FG.textLead)
              .fontColor(FG.ink)
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: FG.line })
          .margin({ top: 4 })
          Row() {
            Text('粗脂肪')
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .layoutWeight(1)
            Text(`${this.dmOf('crudeFatMin')} %`)
              .fontSize(FG.textLead)
              .fontColor(FG.ink)
          }
          .width('100%')
          .padding({ top: 10, bottom: 10 })
          .border({ width: { bottom: 1 }, color: FG.line })
          Text('换算 ＝ 保证值 ÷ DM × 100')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ top: 8 })
            .width('100%')
        } else {
          Text('填写「水分」后自动换算干物质基准，便于与国标（以干物质计）对照。')
            .fontSize(FG.textLabel)
            .lineHeight(20)
            .fontColor(FG.inkMuted)
            .margin({ top: 8 })
            .width('100%')
        }
        Text('仅供阅读换算，提交时仍是包装上的风干基保证值。')
          .fontSize(FG.textLabel)
          .lineHeight(20)
          .fontColor(FG.inkMuted)
          .margin({ top: 8 })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor(FG.paper)
      .borderRadius(FG.radius)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  EnergySection() {
    Column() {
      Text('能量')
        .fontFamily(FG.serif)
        .fontSize(FG.textH3)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .letterSpacing(-0.2)
        .width('100%')
        .margin({ bottom: 16 })

      this.NumberField('标注代谢能', this.kcalText, 'kcal/kg', (value: string) => {
        this.kcalText = value;
      })

      Text(this.kcalText.trim().length === 0 ? '未标注 · 将使用修正 Atwater 估算' : '按包装标注值计算，不做估算')
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ActionBar() {
    Row() {
      Row() {
        FgButton({
          label: '取消',
          variant: 'secondary',
          fillWidth: true,
          onTap: () => {
            Nav.pop();
          }
        })
      }
      .layoutWeight(1)

      Row() {
        FgButton({
          label: this.isEdit() ? '保存修改' : '录入',
          variant: 'primary',
          loading: this.saving,
          fillWidth: true,
          onTap: () => {
            this.save();
          }
        })
      }
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ top: 16 })
  }

  build() {
    Scroll() {
      Column() {
        PageHeader({
          title: this.isEdit() ? '编辑食品' : '录入食品',
          breadcrumb: this.isEdit() ? '食品库 · 编辑' : '食品库 · 录入',
          backLabel: '上一页',
          description: '按包装袋上的「产品成分分析保证值」逐项填写即可，未标注的项留空。',
          onBack: () => {
            Nav.pop();
          }
        })

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(28)
              .height(28)
              .color(FG.accent)
          }
          .width('100%')
          .padding({ top: 64, bottom: 64 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.loadError.length > 0) {
          Column() {
            Text(this.loadError)
              .fontSize(13)
              .fontColor(FG.danger)
              .width('100%')
            FgButton({
              label: '返回食品库',
              variant: 'secondary',
              onTap: () => {
                Nav.pop();
              }
            })
              .margin({ top: 12 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 12, top: 24, bottom: 24 })
          .border({ width: { left: 2 }, color: FG.danger })
        } else {
          Column() {
            this.BasicSection()
            this.SectionDivider()
            this.AnalysisSection()
            this.SectionDivider()
            this.EnergySection()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(FG.surface)
          .border({ width: 1, color: FG.line })
          .borderRadius(FG.radius)

          this.ActionBar()
        }
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
