import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { UploadApi } from '../api/Api';
import { FG } from '../common/Theme';
import { PetAvatarOption, Species } from '../models/Types';
import { avatarBelongsToSpecies, avatarsForSpecies, isRemoteAvatar, petAvatarResource } from '../utils/PetAvatar';
import { speciesFullLabel } from '../utils/Constants';
import { showToast } from '../utils/Http';
import { FgButton } from './FgButton';
import { Icon } from './Icon';

const MAX_SIZE: number = 5 * 1024 * 1024;

@Component
export struct PetAvatarPicker {
  value: string = '';
  species: Species = 'dog';
  onChange: (value: string) => void = () => {
  };
  @State private systemOpen: boolean = false;
  @State private uploading: boolean = false;

  private options(): PetAvatarOption[] {
    return avatarsForSpecies(this.species);
  }

  private systemSelected(): boolean {
    return petAvatarResource(this.value) !== undefined;
  }

  private customSelected(): boolean {
    return isRemoteAvatar(this.value);
  }

  private avatarRes(key: string): Resource {
    const res: Resource | undefined = petAvatarResource(key);
    return res !== undefined ? res : $r('app.media.pet_dog_02');
  }

  private preview(): Resource {
    if (this.systemSelected()) {
      return this.avatarRes(this.value);
    }
    const list: PetAvatarOption[] = this.options();
    return list.length > 0 ? this.avatarRes(list[0].key) : $r('app.media.pet_cat_02');
  }

  private async pickAndUpload(): Promise<void> {
    if (this.uploading) {
      return;
    }
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length === 0) {
        return;
      }
      const uri: string = result.photoUris[0];
      const dot: number = uri.lastIndexOf('.');
      const ext: string = dot >= 0 ? uri.substring(dot + 1).toLowerCase() : '';
      if (ext !== 'jpg' && ext !== 'jpeg' && ext !== 'png' && ext !== 'webp') {
        showToast('仅支持 JPG、PNG、WebP 格式的图片');
        return;
      }

      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      if (stat.size > MAX_SIZE) {
        fs.closeSync(file);
        showToast('图片大小不能超过 5MB');
        return;
      }
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);

      this.uploading = true;
      const mime: string = ext === 'png' ? 'image/png' : (ext === 'webp' ? 'image/webp' : 'image/jpeg');
      const res = await UploadApi.avatar(buffer, `avatar.${ext}`, mime);
      this.onChange(res.url);
      showToast('头像上传成功');
    } catch (err) {
      console.error(`avatar upload failed: ${JSON.stringify(err)}`);
    } finally {
      this.uploading = false;
    }
  }

  private clear(): void {
    this.onChange('');
    this.systemOpen = false;
  }

  @Builder
  systemTile() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Image(this.preview())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      }
      .width('100%')
      .height('100%')

      if (this.systemSelected()) {
        Row() {
          Icon({ name: 'check', iconSize: 11, color: FG.surface, weight: 2.4 })
        }
        .width(16)
        .height(16)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(FG.accent)
        .borderRadius(3)
        .margin({ right: 3, bottom: 3 })
      }
    }
    .width(80)
    .height(80)
    .backgroundColor(FG.paper)
    .border({
      width: this.systemSelected() ? 2 : 1,
      color: this.systemSelected() ? FG.accent : FG.line
    })
    .borderRadius(FG.radius)
    .clip(true)
    .onClick(() => {
      this.systemOpen = true;
    })
  }

  @Builder
  uploadTile() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.customSelected()) {
        Image(this.value)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Column() {
          if (this.uploading) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color(FG.accent)
            Text('上传中')
              .fontSize(11)
              .fontColor(FG.accent)
          } else {
            Icon({ name: 'upload', iconSize: 18, color: FG.inkMuted })
            Text('上传图片')
              .fontSize(11)
              .fontColor(FG.inkMuted)
          }
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
      }

      if (this.customSelected()) {
        Row() {
          Icon({ name: 'check', iconSize: 11, color: FG.surface, weight: 2.4 })
        }
        .width(16)
        .height(16)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(FG.accent)
        .borderRadius(3)
        .margin({ right: 3, bottom: 3 })
      }
    }
    .width(80)
    .height(80)
    .backgroundColor(this.customSelected() ? FG.paper : FG.surface)
    .border({
      width: this.customSelected() ? 2 : 1,
      color: this.customSelected() ? FG.accent : FG.line,
      style: this.customSelected() ? BorderStyle.Solid : BorderStyle.Dashed
    })
    .borderRadius(FG.radius)
    .clip(true)
    .onClick(() => {
      this.pickAndUpload();
    })
  }

  @Builder
  systemSheet() {
    Column() {
      Text(`选择${speciesFullLabel(this.species)}头像`)
        .fontFamily(FG.serif)
        .fontSize(FG.textH3)
        .fontWeight(FontWeight.Bold)
        .fontColor(FG.ink)
        .width('100%')
        .margin({ bottom: 16 })

      Scroll() {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.options(), (option: PetAvatarOption) => {
            Stack({ alignContent: Alignment.BottomEnd }) {
              Image(this.avatarRes(option.key))
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
              if (this.value === option.key) {
                Row() {
                  Icon({ name: 'check', iconSize: 11, color: FG.surface, weight: 2.4 })
                }
                .width(16)
                .height(16)
                .justifyContent(FlexAlign.Center)
                .backgroundColor(FG.accent)
                .borderRadius(3)
                .margin({ right: 3, bottom: 3 })
              }
            }
            .width('22%')
            .aspectRatio(1)
            .margin({ right: '2%', bottom: 10 })
            .border({
              width: this.value === option.key ? 2 : 1,
              color: this.value === option.key ? FG.accent : FG.line
            })
            .borderRadius(FG.radius)
            .clip(true)
            .onClick(() => {
              this.onChange(option.key);
              this.systemOpen = false;
            })
          }, (option: PetAvatarOption) => option.key)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)

      Row() {
        if (this.value !== '') {
          FgButton({
            label: '清除头像',
            variant: 'text',
            small: true,
            onTap: () => {
              this.clear();
            }
          })
        }
        Blank()
        FgButton({
          label: '取消',
          variant: 'secondary',
          small: true,
          onTap: () => {
            this.systemOpen = false;
          }
        })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 20, bottom: 24 })
    .backgroundColor(FG.surface)
  }

  build() {
    Column() {
      Row() {
        Column() {
          this.systemTile()
          Text('系统头像')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)

        Column() {
          this.uploadTile()
          Text('上传头像')
            .fontSize(FG.textLabel)
            .fontColor(FG.inkMuted)
            .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 24 })
      }
      .width('100%')

      Row() {
        Text('系统头像点开后可挑选，也可上传本地图片（JPG / PNG / WebP，≤ 5MB）。')
          .fontSize(FG.textLabel)
          .lineHeight(19)
          .fontColor(FG.inkMuted)
          .layoutWeight(1)
        if (this.value !== '') {
          Text('清除头像')
            .fontSize(FG.textLabel)
            .fontColor(FG.accent)
            .margin({ left: 12 })
            .onClick(() => {
              this.clear();
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ top: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .bindSheet($$this.systemOpen, this.systemSheet(), {
      height: 460,
      dragBar: true,
      backgroundColor: FG.surface,
      showClose: false
    })
  }
}
