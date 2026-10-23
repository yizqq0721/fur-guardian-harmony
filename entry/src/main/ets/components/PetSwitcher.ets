import { FG } from '../common/Theme';
import { Pet } from '../models/Types';
import { PetStore } from '../stores/PetStore';
import { Icon } from './Icon';

@Component
export struct PetSwitcher {
  @StorageLink('fg_pets') pets: Pet[] = [];
  @StorageLink('fg_currentPetId') currentPetId: number = 0;
  plain: boolean = false;
  onChange: (id: number) => void = () => {
  };

  private current(): Pet | undefined {
    return this.pets.find((pet: Pet) => pet.id === this.currentPetId) ?? this.pets[0];
  }

  private menu(): MenuElement[] {
    const items: MenuElement[] = [];
    this.pets.forEach((pet: Pet) => {
      items.push({
        value: pet.breed ? `${pet.name} · ${pet.breed}` : pet.name,
        action: () => {
          PetStore.setCurrentPet(pet.id);
          this.onChange(pet.id);
        }
      });
    });
    if (items.length === 0) {
      items.push({ value: '暂无宠物', action: () => {
      }, enabled: false });
    }
    return items;
  }

  @Builder
  content() {
    Row() {
      Icon({
        name: this.current()?.species === 'cat' ? 'cat' : 'dog',
        iconSize: 16,
        color: this.plain ? FG.ink : FG.accent
      })
      Text(this.current()?.name ?? '选择宠物')
        .fontSize(FG.textBody)
        .fontColor(FG.ink)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 6 })
        .flexShrink(1)
      if (this.pets.length > 1) {
        Icon({ name: 'chevron-down', iconSize: 14, color: FG.inkMuted })
          .margin({ left: 2 })
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  build() {
    if (this.pets.length > 1) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        this.content()
      }
      .height(34)
      .constraintSize({ maxWidth: 92 })
      .padding({ left: 4, right: 2 })
      .borderRadius(FG.radius)
      .backgroundColor(this.plain ? '#00000000' : FG.surface)
      .border({
        width: this.plain ? 0 : 1,
        color: this.plain ? '#00000000' : FG.line
      })
      .bindMenu(this.menu())
    } else if (this.current() !== undefined) {
      Row() {
        this.content()
      }
      .height(34)
      .constraintSize({ maxWidth: 92 })
    }
  }
}
