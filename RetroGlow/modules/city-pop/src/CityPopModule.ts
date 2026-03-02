import { NativeModule, requireNativeModule } from 'expo';

import { CityPopModuleEvents } from './CityPop.types';

declare class CityPopModule extends NativeModule<CityPopModuleEvents> {
  PI: number;
  hello(): string;
  setValueAsync(value: string): Promise<void>;
}

// This call loads the native module object from the JSI.
export default requireNativeModule<CityPopModule>('CityPop');
