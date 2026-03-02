import { registerWebModule, NativeModule } from 'expo';

import { ChangeEventPayload } from './CityPop.types';

type CityPopModuleEvents = {
  onChange: (params: ChangeEventPayload) => void;
}

class CityPopModule extends NativeModule<CityPopModuleEvents> {
  PI = Math.PI;
  async setValueAsync(value: string): Promise<void> {
    this.emit('onChange', { value });
  }
  hello() {
    return 'Hello world! 👋';
  }
};

export default registerWebModule(CityPopModule, 'CityPopModule');
