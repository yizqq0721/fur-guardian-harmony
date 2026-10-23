import { PetAvatarOption, Species } from '../models/Types';

/** 与 Vue petAvatar.ts 相同的稳定 key（数据库里保存的是中文文件名） */
export const PET_AVATAR_OPTIONS: PetAvatarOption[] = [
  { key: '萌宠猫咪肖像集-02.png', species: 'cat', resource: 'pet_cat_02' },
  { key: '萌宠猫咪肖像集-03.png', species: 'cat', resource: 'pet_cat_03' },
  { key: '萌宠猫咪肖像集-04.png', species: 'cat', resource: 'pet_cat_04' },
  { key: '萌宠猫咪肖像集-05.png', species: 'cat', resource: 'pet_cat_05' },
  { key: '萌宠猫咪肖像集-06.png', species: 'cat', resource: 'pet_cat_06' },
  { key: '萌宠猫咪肖像集-07.png', species: 'cat', resource: 'pet_cat_07' },
  { key: '萌宠猫咪肖像集-08.png', species: 'cat', resource: 'pet_cat_08' },
  { key: '萌宠猫咪肖像集-09.png', species: 'cat', resource: 'pet_cat_09' },
  { key: '萌犬肖像集-02.png', species: 'dog', resource: 'pet_dog_02' },
  { key: '萌犬肖像集-03.png', species: 'dog', resource: 'pet_dog_03' },
  { key: '萌犬肖像集-04.png', species: 'dog', resource: 'pet_dog_04' },
  { key: '萌犬肖像集-06.png', species: 'dog', resource: 'pet_dog_06' },
  { key: '萌犬肖像集-07.png', species: 'dog', resource: 'pet_dog_07' },
  { key: '萌犬肖像集-09.png', species: 'dog', resource: 'pet_dog_09' },
  { key: '萌犬肖像集2-01.png', species: 'dog', resource: 'pet_dog2_01' },
  { key: '萌犬肖像集2-02.png', species: 'dog', resource: 'pet_dog2_02' },
  { key: '萌犬肖像集2-03.png', species: 'dog', resource: 'pet_dog2_03' },
  { key: '萌犬肖像集2-04.png', species: 'dog', resource: 'pet_dog2_04' },
  { key: '萌犬肖像集2-05.png', species: 'dog', resource: 'pet_dog2_05' },
  { key: '萌犬肖像集2-06.png', species: 'dog', resource: 'pet_dog2_06' },
  { key: '萌犬肖像集2-08.png', species: 'dog', resource: 'pet_dog2_08' },
  { key: '萌犬肖像集2-09.png', species: 'dog', resource: 'pet_dog2_09' },
  { key: '萌猫品种肖像合集-02.png', species: 'cat', resource: 'pet_cat_breed_02' },
  { key: '萌猫品种肖像合集-03.png', species: 'cat', resource: 'pet_cat_breed_03' },
  { key: '萌猫品种肖像合集-04.png', species: 'cat', resource: 'pet_cat_breed_04' },
  { key: '萌猫品种肖像合集-06.png', species: 'cat', resource: 'pet_cat_breed_06' },
  { key: '萌猫品种肖像合集-07.png', species: 'cat', resource: 'pet_cat_breed_07' },
  { key: '萌猫品种肖像合集-09.png', species: 'cat', resource: 'pet_cat_breed_09' }
];

function resourceByName(name: string): Resource | undefined {
  switch (name) {
    case 'pet_cat_02': return $r('app.media.pet_cat_02');
    case 'pet_cat_03': return $r('app.media.pet_cat_03');
    case 'pet_cat_04': return $r('app.media.pet_cat_04');
    case 'pet_cat_05': return $r('app.media.pet_cat_05');
    case 'pet_cat_06': return $r('app.media.pet_cat_06');
    case 'pet_cat_07': return $r('app.media.pet_cat_07');
    case 'pet_cat_08': return $r('app.media.pet_cat_08');
    case 'pet_cat_09': return $r('app.media.pet_cat_09');
    case 'pet_dog_02': return $r('app.media.pet_dog_02');
    case 'pet_dog_03': return $r('app.media.pet_dog_03');
    case 'pet_dog_04': return $r('app.media.pet_dog_04');
    case 'pet_dog_06': return $r('app.media.pet_dog_06');
    case 'pet_dog_07': return $r('app.media.pet_dog_07');
    case 'pet_dog_09': return $r('app.media.pet_dog_09');
    case 'pet_dog2_01': return $r('app.media.pet_dog2_01');
    case 'pet_dog2_02': return $r('app.media.pet_dog2_02');
    case 'pet_dog2_03': return $r('app.media.pet_dog2_03');
    case 'pet_dog2_04': return $r('app.media.pet_dog2_04');
    case 'pet_dog2_05': return $r('app.media.pet_dog2_05');
    case 'pet_dog2_06': return $r('app.media.pet_dog2_06');
    case 'pet_dog2_08': return $r('app.media.pet_dog2_08');
    case 'pet_dog2_09': return $r('app.media.pet_dog2_09');
    case 'pet_cat_breed_02': return $r('app.media.pet_cat_breed_02');
    case 'pet_cat_breed_03': return $r('app.media.pet_cat_breed_03');
    case 'pet_cat_breed_04': return $r('app.media.pet_cat_breed_04');
    case 'pet_cat_breed_06': return $r('app.media.pet_cat_breed_06');
    case 'pet_cat_breed_07': return $r('app.media.pet_cat_breed_07');
    case 'pet_cat_breed_09': return $r('app.media.pet_cat_breed_09');
    default: return undefined;
  }
}

/** 数据库头像 key → 本地资源；外链头像直接返回 undefined（由调用方处理远程 URL） */
export function petAvatarResource(avatar?: string | null): Resource | undefined {
  if (!avatar) {
    return undefined;
  }
  const option: PetAvatarOption | undefined = PET_AVATAR_OPTIONS.find((item: PetAvatarOption) => item.key === avatar);
  return option ? resourceByName(option.resource) : undefined;
}

export function isRemoteAvatar(avatar?: string | null): boolean {
  if (!avatar) {
    return false;
  }
  return avatar.startsWith('http://') || avatar.startsWith('https://') || avatar.startsWith('/');
}

export function avatarBelongsToSpecies(avatar: string | null | undefined, species: Species): boolean {
  if (!avatar) {
    return true;
  }
  const option: PetAvatarOption | undefined = PET_AVATAR_OPTIONS.find((item: PetAvatarOption) => item.key === avatar);
  return option === undefined ? true : option.species === species;
}

export function avatarsForSpecies(species: Species): PetAvatarOption[] {
  return PET_AVATAR_OPTIONS.filter((item: PetAvatarOption) => item.species === species);
}
