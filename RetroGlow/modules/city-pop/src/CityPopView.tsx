import { requireNativeView } from 'expo';
import * as React from 'react';

import { CityPopViewProps } from './CityPop.types';

const NativeView: React.ComponentType<CityPopViewProps> =
  requireNativeView('CityPop');

export default function CityPopView(props: CityPopViewProps) {
  return <NativeView {...props} />;
}
