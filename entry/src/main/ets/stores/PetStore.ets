import { PetApi } from '../api/Api';
import { Pet } from '../models/Types';

export class PetStore {
  static async fetchPets(force: boolean = false): Promise<Pet[]> {
    const loaded: boolean = AppStorage.get<boolean>('fg_petsLoaded') === true;
    const cached: Pet[] | undefined = AppStorage.get<Pet[]>('fg_pets');
    if (loaded && !force && cached !== undefined) {
      return cached;
    }
    const list: Pet[] = await PetApi.list();
    AppStorage.setOrCreate('fg_pets', list);
    AppStorage.setOrCreate('fg_petsLoaded', true);
    if (list.length > 0) {
      const currentId: number = AppStorage.get<number>('fg_currentPetId') ?? 0;
      const exists: boolean = list.some((pet: Pet) => pet.id === currentId);
      if (!exists) {
        PetStore.setCurrentPet(list[0].id);
      }
    }
    return list;
  }

  static setCurrentPet(id: number): void {
    AppStorage.setOrCreate('fg_currentPetId', id);
  }

  static currentPet(): Pet | undefined {
    const pets: Pet[] | undefined = AppStorage.get<Pet[]>('fg_pets');
    const currentId: number = AppStorage.get<number>('fg_currentPetId') ?? 0;
    if (pets === undefined || pets.length === 0) {
      return undefined;
    }
    const current: Pet | undefined = pets.find((pet: Pet) => pet.id === currentId);
    return current ?? pets[0];
  }

  static reset(): void {
    AppStorage.setOrCreate('fg_pets', [] as Pet[]);
    AppStorage.setOrCreate('fg_petsLoaded', false);
    AppStorage.setOrCreate('fg_currentPetId', 0);
  }
}
