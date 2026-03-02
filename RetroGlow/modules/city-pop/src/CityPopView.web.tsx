import * as React from 'react';

import { CityPopViewProps } from './CityPop.types';

export default function CityPopView(props: CityPopViewProps) {
  return (
    <div>
      <iframe
        style={{ flex: 1 }}
        src={props.url}
        onLoad={() => props.onLoad({ nativeEvent: { url: props.url } })}
      />
    </div>
  );
}
