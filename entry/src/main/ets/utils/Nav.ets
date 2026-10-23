export class EmptyParam {
}

export const EMPTY_PARAM: EmptyParam = new EmptyParam();

export class Nav {
  static stack(): NavPathStack | undefined {
    return AppStorage.get<NavPathStack>('fg_pathStack');
  }

  static push(name: string, param: Object = EMPTY_PARAM): void {
    const stack: NavPathStack | undefined = Nav.stack();
    if (stack) {
      stack.pushPathByName(name, param);
    }
  }

  static pop(): void {
    const stack: NavPathStack | undefined = Nav.stack();
    if (stack) {
      stack.pop();
    }
  }

  static clear(): void {
    const stack: NavPathStack | undefined = Nav.stack();
    if (stack) {
      stack.clear();
    }
  }
}
