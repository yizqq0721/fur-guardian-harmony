import { FG } from '../common/Theme';
import { isRemoteAvatar, petAvatarResource } from '../utils/PetAvatar';

/** 宠物头像：系统头像资源 / 远程图片 / 名字首字兜底 */
@Component
export struct PetAvatarView {
  @Prop avatar: string = '';
  @Prop name: string = '';
  avatarSize: number = 96;
  corner: number = FG.radius;
  textSize: number = 32;

  private avatarRes(): Resource {
    const res: Resource | undefined = petAvatarResource(this.avatar);
    return res !== undefined ? res : $r('app.media.pet_dog_02');
  }

  private initial(): string {
    return this.name.length > 0 ? this.name.substring(0, 1) : '?';
  }

  build() {
    Stack() {
      if (isRemoteAvatar(this.avatar)) {
        Image(this.avatar)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else if (petAvatarResource(this.avatar) !== undefined) {
        Image(this.avatarRes())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Text(this.initial())
          .fontFamily(FG.serif)
          .fontSize(this.textSize)
          .fontWeight(FontWeight.Bold)
          .fontColor(FG.accent)
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
    .backgroundColor(FG.accentSoft)
    .border({ width: 1, color: FG.line })
    .borderRadius(this.corner)
    .clip(true)
  }
}
