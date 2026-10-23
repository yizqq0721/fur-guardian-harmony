import { FoodApi, NutritionApi, PetApi } from '../api/Api';
import { FG } from '../common/Theme';
import { DisclaimerBar } from '../components/DisclaimerBar';
import { EmptyState } from '../components/EmptyState';
import { FgButton } from '../components/FgButton';
import { FgChip } from '../components/FgChip';
import { Icon } from '../components/Icon';
import { MarkdownView } from '../components/MarkdownView';
import { NutrientTable } from '../components/NutrientTable';
import { PageHeader } from '../components/PageHeader';
import { StatTile } from '../components/StatTile';
import { StepTimeline, TimelineStep } from '../components/StepTimeline';
import { Food, NutritionPlan, NutritionRecipe, Pet, RecipeSnack, RecipeSource, WeightLog } from '../models/Types';
import { PetStore } from '../stores/PetStore';
import { ageText } from '../utils/Format';
import { showToast } from '../utils/Http';
import { Nav } from '../utils/Nav';

function fmt(n?: number): string {
  return n === undefined || n === null ? '—' : String(Math.round(n));
}

/** 后端把计算过程拼成多行文本，这里按行还原成时间线（与 Vue parseProcess 一致） */
function parseProcess(text: string): TimelineStep[] {
  const lines: string[] = text.split('\n').map((line: string) => line.trim()).filter((line: string) => line.length > 0);
  return lines.map((line: string) => {
    const eq: number = line.indexOf('=');
    const formula: string = eq >= 0 ? line.substring(eq + 1).trim() : '';
    const label: string = eq >= 0 ? line.substring(0, eq).trim() : line;
    const matched: RegExpMatchArray | null = formula.match(/([\d.,]+\s*(?:kcal[^=]*|g[^=]*|%)?)$/);
    const result: string = matched !== null ? matched[1].trim() : '';
    const step: TimelineStep = {
      label: label.replace(/[:：]$/, ''),
      formula: formula.length > 0 ? formula : undefined,
      result: result.length > 0 && result !== formula ? result : undefined
    };
    return step;
  });
}

/** 与 Vue NutritionView 的移动端布局一致：上下文条 + 指标/计算/达标 + 侧栏卡片堆叠 */
@Component
export struct NutritionPage {
  @Prop petId: number = 0;
  @StorageLink('fg_pets') pets: Pet[] = [];
  @StorageLink('fg_currentPetId') currentPetId: number = 0;
  @StorageLink('fg_foodsDirty') @Watch('onFoodsDirty') foodsDirty: boolean = false;
  @State private allFoods: Food[] = [];
  @State private foodId: number = 0;
  @State private plan: NutritionPlan | null = null;
  @State private calculating: boolean = false;
  @State private latestWeight: WeightLog | null = null;
  @State private recipe: NutritionRecipe | null = null;
  @State private recipeLoading: boolean = false;
  @State private foodSheet: boolean = false;
  @State private foodKeyword: string = '';
  private recipeSeq: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  private effectivePetId(): number {
    return this.petId > 0 ? this.petId : this.currentPetId;
  }

  private pet(): Pet | undefined {
    return this.pets.find((item: Pet) => item.id === this.effectivePetId());
  }

  private async load(): Promise<void> {
    try {
      if (this.pets.length === 0) {
        await PetStore.fetchPets();
      }
    } catch (err) {
      console.error(`load pets failed: ${JSON.stringify(err)}`);
    }
    await this.loadFoods();
    this.loadLatestWeight();
  }

  private async loadFoods(): Promise<void> {
    try {
      const page = await FoodApi.list({ page: 1, size: 100 });
      this.allFoods = page.records ?? [];
    } catch (err) {
      console.error(`load foods failed: ${JSON.stringify(err)}`);
      this.allFoods = [];
    }
  }

  private async loadLatestWeight(): Promise<void> {
    const id: number = this.effectivePetId();
    if (id <= 0) {
      return;
    }
    try {
      const history: WeightLog[] = await PetApi.weightHistory(id);
      this.latestWeight = history.length > 0 ? history[history.length - 1] : null;
    } catch (err) {
      this.latestWeight = null;
    }
  }

  private onFoodsDirty(): void {
    if (this.foodsDirty) {
      this.foodsDirty = false;
      this.reloadFoods();
    }
  }

  private async reloadFoods(): Promise<void> {
    await this.loadFoods();
    if (this.foodId > 0 && !this.allFoods.some((food: Food) => food.id === this.foodId)) {
      this.foodId = 0;
      this.plan = null;
      this.recipe = null;
    }
  }

  /** 主粮只保留全价/补充粮，并按宠物物种过滤：猫选 CAT/BOTH，狗选 DOG/BOTH */
  private foods(): Food[] {
    const speciesScope: string = this.pet()?.species === 'dog' ? 'DOG' : (this.pet()?.species === 'cat' ? 'CAT' : '');
    return this.allFoods.filter((food: Food) => {
      if (food.productType !== undefined && food.productType !== 'COMPLETE' && food.productType !== 'COMPLEMENTARY') {
        return false;
      }
      if (speciesScope.length === 0 || food.speciesScope === undefined || food.speciesScope === 'BOTH') {
        return true;
      }
      return food.speciesScope === speciesScope;
    });
  }

  private filteredFoods(): Food[] {
    const keyword: string = this.foodKeyword.trim().toLowerCase();
    if (keyword.length === 0) {
      return this.foods();
    }
    return this.foods().filter((food: Food) => this.foodTitle(food).toLowerCase().includes(keyword));
  }

  private foodTitle(food: Food): string {
    return `${food.brand !== undefined && food.brand.length > 0 ? `${food.brand} ` : ''}${food.name}`;
  }

  private selectedFood(): Food | undefined {
    return this.allFoods.find((food: Food) => food.id === this.foodId);
  }

  private petMeta(): string {
    const pet: Pet | undefined = this.pet();
    if (pet === undefined) {
      return '';
    }
    const bits: string[] = [];
    if (pet.breed !== undefined && pet.breed.length > 0) {
      bits.push(pet.breed);
    }
    bits.push(ageText(pet.birthday));
    if (pet.neutered === true || pet.neutered === 1) {
      bits.push('已绝育');
    }
    if (this.latestWeight !== null) {
      bits.push(`${this.latestWeight.weightKg} kg`);
    }
    if (pet.bcs !== undefined && pet.bcs !== null) {
      bits.push(`BCS ${pet.bcs}/9`);
    }
    return bits.join(' · ');
  }

  private merCoefficient(): string {
    const plan: NutritionPlan | null = this.plan;
    if (plan === null || plan.rerKcal === 0) {
      return '—';
    }
    return (plan.merKcal / plan.rerKcal).toFixed(2);
  }

  private calcSteps(): TimelineStep[] {
    const plan: NutritionPlan | null = this.plan;
    return plan === null ? [] : parseProcess(plan.calculationProcess ?? '');
  }

  private async calculate(): Promise<void> {
    const petId: number = this.effectivePetId();
    if (petId <= 0) {
      showToast('请先完善宠物档案');
      return;
    }
    if (this.foodId <= 0) {
      return;
    }
    this.calculating = true;
    this.recipeSeq++;
    this.recipe = null;
    try {
      this.plan = await NutritionApi.calculate(petId, this.foodId);
      this.loadRecipe();
    } catch (err) {
      console.error(`calculate failed: ${JSON.stringify(err)}`);
      this.plan = null;
      showToast('计算失败，请确认宠物档案完整');
    } finally {
      this.calculating = false;
    }
  }

  private async loadRecipe(): Promise<void> {
    const petId: number = this.effectivePetId();
    if (petId <= 0 || this.foodId <= 0) {
      return;
    }
    const seq: number = ++this.recipeSeq;
    this.recipeLoading = true;
    this.recipe = null;
    try {
      const result: NutritionRecipe = await NutritionApi.recipe(petId, this.foodId);
      if (seq === this.recipeSeq) {
        this.recipe = result;
      }
    } catch (err) {
      if (seq === this.recipeSeq) {
        showToast('食谱建议生成失败，请稍后重试');
      }
    } finally {
      if (seq === this.recipeSeq) {
        this.recipeLoading = false;
      }
    }
  }

  private selectFood(food: Food): void {
    const changed: boolean = this.foodId !== food.id;
    this.foodId = food.id;
    this.foodSheet = false;
    this.foodKeyword = '';
    if (changed) {
      this.calculate();
    }
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontFamily(FG.serif)
      .fontSize(FG.textH3)
      .fontWeight(FontWeight.Bold)
      .fontColor(FG.ink)
      .letterSpacing(-0.2)
      .width('100%')
      .margin({ bottom: 12 })
  }

  @Builder
  ContextBar() {
    Column() {
      Row() {
        Column() {
          Icon({
            name: this.pet()?.species === 'cat' ? 'cat' : 'dog',
            iconSize: 20,
            color: FG.accent
          })
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(18)
        .border({ width: 1, color: FG.line })
        .backgroundColor(FG.paper)

        Column() {
          Text(this.pet() !== undefined ? (this.pet() as Pet).name : '未选择宠物')
            .fontFamily(FG.serif)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(FG.ink)
            .width('100%')
          Text(this.petMeta())
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ top: 2 })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column() {
        Text('当前主粮')
          .fontSize(FG.textLabel)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(0.5)
          .fontColor(FG.inkMuted)
          .width('100%')
          .margin({ bottom: 4 })
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row() {
            Text(this.selectedFood() !== undefined ? this.foodTitle(this.selectedFood() as Food) : '从食品库选择主粮')
              .fontSize(15)
              .fontColor(this.selectedFood() !== undefined ? FG.ink : FG.inkMuted)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .textAlign(TextAlign.Start)
            Icon({ name: 'chevron-down', iconSize: 16, color: FG.inkMuted })
          }
          .width('100%')
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })
        .backgroundColor(FG.surface)
        .borderRadius(FG.radius)
        .border({ width: 1, color: FG.line })
        .onClick(() => {
          this.foodSheet = true;
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 12 })

      Row() {
        Blank()
        Text('没收录？去录入')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .height(44)
          .padding({ left: 8, right: 8 })
          .onClick(() => {
            Nav.push('FoodForm');
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ bottom: 16 })
  }

  @Builder
  HeroCard(plan: NutritionPlan) {
    Column() {
      StatTile({
        label: 'MER 每日维持能量',
        value: fmt(plan.merKcal),
        unit: 'kcal/日',
        caption: `RER ${fmt(plan.rerKcal)} kcal × ${this.merCoefficient()}`
      })
      Divider()
        .color(FG.line)
        .strokeWidth(1)
        .margin({ top: 16, bottom: 16 })
      StatTile({
        label: '每日主粮',
        value: fmt(plan.mainFoodGrams),
        unit: 'g',
        hero: true,
        caption: `≈ ${fmt(plan.gramsPerMeal)} g/餐 × ${plan.mealsPerDay} 餐`
      })
      Divider()
        .color(FG.line)
        .strokeWidth(1)
        .margin({ top: 16, bottom: 16 })
      StatTile({
        label: '零食额度',
        value: fmt(plan.snackBudgetKcal),
        unit: 'kcal',
        caption: '占 MER 10% 硬上限'
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ bottom: 16 })
  }

  @Builder
  CalculationCard() {
    Column() {
      this.SectionTitle('我们怎么算的')
      StepTimeline({ steps: this.calcSteps() })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ bottom: 16 })
  }

  @Builder
  ValidationCard(plan: NutritionPlan) {
    Column() {
      this.SectionTitle('营养达标判定')
      NutrientTable({ rows: plan.validations ?? [] })
      Text('国标是及格线，不等于最适合你家宠物。')
        .fontSize(FG.textLabel)
        .fontColor(FG.inkMuted)
        .width('100%')
        .padding({ top: 12 })
        .margin({ top: 16 })
        .border({ width: { top: 1 }, color: FG.line })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ bottom: 16 })
  }

  @Builder
  DensityCard(plan: NutritionPlan) {
    Column() {
      this.SectionTitle('能量密度')
      Row() {
        Text(`${plan.energyDensityKcalPer100g}`)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
        Text('kcal/100g')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .margin({ left: 4 })
      }
      .alignItems(VerticalAlign.Bottom)
      .width('100%')
      Text(plan.energyEstimated ? '该粮未标注代谢能，下方数值由修正 Atwater 公式估算。' : '取自包装标注的代谢能。')
        .fontSize(FG.textLabel)
        .lineHeight(20)
        .fontColor(FG.inkMuted)
        .margin({ top: 8, bottom: 12 })
        .width('100%')
      FgChip({
        label: plan.energyEstimated ? 'Atwater 估算' : '标注值',
        tone: plan.energyEstimated ? 'warn' : 'ok'
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ bottom: 16 })
  }

  @Builder
  RecipeChip(label: string) {
    Text(label)
      .fontSize(FG.textLabel)
      .fontColor(FG.inkMuted)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(FG.paper)
      .border({ width: 1, color: FG.line })
      .borderRadius(6)
      .margin({ right: 8, bottom: 8 })
  }

  @Builder
  RecipeLoading() {
    Column() {
      Row() {
        LoadingProgress()
          .width(16)
          .height(16)
          .color(FG.accent)
        Text('正在结合主粮、零食与知识库生成…')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 8 })
      ForEach([100, 92, 96, 72], (width: number) => {
        Column()
          .width(`${width}%`)
          .height(12)
          .borderRadius(4)
          .backgroundColor(FG.line)
          .margin({ bottom: 8 })
      }, (width: number) => `sk-${width}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: 12 })
  }

  @Builder
  RecipeCard() {
    Column() {
      Row() {
        Text('每日食谱建议')
          .fontFamily(FG.serif)
          .fontSize(FG.textH3)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.ink)
          .letterSpacing(-0.2)
          .layoutWeight(1)
        if (!this.recipeLoading) {
          Row() {
            Icon({ name: 'refresh-cw', iconSize: 14, color: this.calculating ? FG.inkMuted : FG.accent })
            Text('重新生成')
              .fontSize(FG.textLabel)
              .fontColor(this.calculating ? FG.inkMuted : FG.accent)
              .margin({ left: 4 })
          }
          .height(40)
          .padding({ left: 6, right: 6 })
          .onClick(() => {
            if (!this.calculating) {
              this.loadRecipe();
            }
          })
        }
      }
      .width('100%')

      if (this.recipeLoading) {
        this.RecipeLoading()
      } else if (this.recipe !== null) {
        if ((this.recipe as NutritionRecipe).isFallback) {
          Text('AI 暂时不可用，以下为按计算结果生成的确定性建议。')
            .fontSize(FG.textLabel)
            .lineHeight(20)
            .fontColor(FG.inkMuted)
            .width('100%')
            .padding({ left: 12, top: 8, bottom: 8 })
            .margin({ top: 12 })
            .border({ width: { left: 2 }, color: FG.warning })
            .backgroundColor(FG.paper)
        }
        Column() {
          MarkdownView({ content: (this.recipe as NutritionRecipe).content })
        }
        .width('100%')
        .margin({ top: 12 })

        if ((this.recipe as NutritionRecipe).snacks.length > 0) {
          Column() {
            Text('本次参考零食')
              .fontSize(FG.textLabel)
              .fontWeight(FontWeight.Medium)
              .letterSpacing(0.5)
              .fontColor(FG.inkMuted)
              .width('100%')
              .margin({ bottom: 8 })
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach((this.recipe as NutritionRecipe).snacks, (snack: RecipeSnack) => {
                this.RecipeChip(`${snack.brand !== undefined && snack.brand.length > 0 ? `${snack.brand} ` : ''}${snack.name}${snack.maxGrams !== undefined && snack.maxGrams !== null ? ` · 单种上限 ${snack.maxGrams} g` : ''}`)
              }, (snack: RecipeSnack) => `snack-${snack.id}`)
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 12 })
          .margin({ top: 16 })
          .border({ width: { top: 1 }, color: FG.line })
        }

        if ((this.recipe as NutritionRecipe).sources.length > 0) {
          Column() {
            Text('知识来源')
              .fontSize(FG.textLabel)
              .fontWeight(FontWeight.Medium)
              .letterSpacing(0.5)
              .fontColor(FG.inkMuted)
              .width('100%')
              .margin({ bottom: 8 })
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach((this.recipe as NutritionRecipe).sources, (source: RecipeSource) => {
                this.RecipeChip(source.title)
              }, (source: RecipeSource) => `src-${source.docId}`)
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 12 })
          .margin({ top: 16 })
          .border({ width: { top: 1 }, color: FG.line })
        }
      } else {
        Text('计算完成后，这里会生成可执行的每日食谱。')
          .fontSize(FG.textLabel)
          .lineHeight(20)
          .fontColor(FG.inkMuted)
          .margin({ top: 12 })
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ bottom: 16 })
  }

  @Builder
  Callout(text: string, danger: boolean) {
    Text(text)
      .fontSize(FG.textBody)
      .lineHeight(24)
      .fontColor(FG.ink)
      .width('100%')
      .padding({ left: 16, top: 12, bottom: 12 })
      .border({ width: { left: 2 }, color: danger ? FG.danger : FG.warning })
      .margin({ bottom: 12 })
  }

  @Builder
  WarningsCard(plan: NutritionPlan) {
    Column() {
      this.SectionTitle('需要注意')
      if (plan.weightAdvice !== undefined && plan.weightAdvice !== null && plan.weightAdvice.length > 0) {
        this.Callout(plan.weightAdvice, plan.overweight || plan.underweight)
      }
      ForEach(plan.warnings ?? [], (warning: string, index: number) => {
        this.Callout(warning, false)
      }, (warning: string, index: number) => `warn-${index}`)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(FG.surface)
    .border({ width: 1, color: FG.line })
    .borderRadius(FG.radius)
    .margin({ bottom: 16 })
  }

  @Builder
  FoodRow(food: Food, selected: boolean) {
    Row() {
      Column() {
        Text(this.foodTitle(food))
          .fontSize(15)
          .fontColor(FG.ink)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(food.labeledMeKcal !== undefined && food.labeledMeKcal !== null ? `${food.labeledMeKcal} kcal/kg` : '代谢能未标注')
          .fontSize(FG.textLabel)
          .fontColor(FG.inkMuted)
          .margin({ top: 2 })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (selected) {
        Icon({ name: 'check', iconSize: 18, color: FG.accent, weight: 2.4 })
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: FG.line })
    .onClick(() => {
      this.selectFood(food);
    })
  }

  @Builder
  FoodSheet() {
    Column() {
      Text('选择主粮')
        .fontFamily(FG.serif)
        .fontSize(FG.textH3)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .width('100%')
        .margin({ bottom: 12 })

      Row() {
        Icon({ name: 'search', iconSize: 16, color: FG.inkMuted })
        TextInput({ text: this.foodKeyword, placeholder: '搜索品牌或名称' })
          .layoutWeight(1)
          .height(42)
          .fontSize(15)
          .fontColor(FG.ink)
          .placeholderColor(FG.inkMuted)
          .backgroundColor('#00000000')
          .padding({ left: 8, right: 4 })
          .onChange((value: string) => {
            this.foodKeyword = value;
          })
      }
      .width('100%')
      .height(42)
      .padding({ left: 12, right: 4 })
      .backgroundColor(FG.surface)
      .border({ width: 1, color: FG.line })
      .borderRadius(FG.radius)
      .margin({ bottom: 8 })

      Scroll() {
        Column() {
          if (this.filteredFoods().length === 0) {
            Text('没有可用的主粮，去食品库录入吧')
              .fontSize(FG.textBody)
              .fontColor(FG.inkMuted)
              .width('100%')
              .padding({ top: 32, bottom: 32 })
              .textAlign(TextAlign.Center)
          } else {
            ForEach(this.filteredFoods(), (food: Food) => {
              this.FoodRow(food, food.id === this.foodId)
            }, (food: Food) => `sheet-food-${food.id}`)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 8, bottom: 16 })
  }

  build() {
    Scroll() {
      Column() {
        PageHeader({
          title: '营养方案',
          breadcrumb: this.pet() !== undefined ? `${(this.pet() as Pet).name} · 营养方案` : '营养方案',
          backLabel: '我的宠物',
          description: '按个体数据算出每日热量与克数，并对照国标逐项判定该粮是否达标。',
          showActions: true,
          onBack: () => {
            Nav.pop();
          }
        }) {
          if (this.foodId > 0) {
            FgButton({
              label: '重新计算',
              variant: 'secondary',
              loading: this.calculating,
              onTap: () => {
                this.calculate();
              }
            })
          }
        }

        this.ContextBar()

        if (this.calculating && this.plan === null) {
          Column() {
            LoadingProgress()
              .width(28)
              .height(28)
              .color(FG.accent)
            Text('正在计算营养方案…')
              .fontSize(FG.textLabel)
              .fontColor(FG.inkMuted)
              .margin({ top: 8 })
          }
          .width('100%')
          .padding({ top: 48, bottom: 48 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.plan !== null) {
          this.HeroCard(this.plan as NutritionPlan)
          this.CalculationCard()
          this.ValidationCard(this.plan as NutritionPlan)
          this.DensityCard(this.plan as NutritionPlan)
          this.RecipeCard()
          if (((this.plan as NutritionPlan).weightAdvice !== undefined && (this.plan as NutritionPlan).weightAdvice !== null) ||
            ((this.plan as NutritionPlan).warnings?.length ?? 0) > 0) {
            this.WarningsCard(this.plan as NutritionPlan)
          }
          DisclaimerBar()
        } else {
          EmptyState({
            variant: 'foods',
            description: '选择主粮后生成个体化营养方案'
          })
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
    .bindSheet($$this.foodSheet, this.FoodSheet(), {
      height: 600,
      dragBar: true,
      backgroundColor: FG.surface,
      showClose: true
    })
  }
}
