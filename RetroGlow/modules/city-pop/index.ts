// Reexport the native module. On web, it will be resolved to CityPopModule.web.ts
// and on native platforms to CityPopModule.ts
export { default } from './src/CityPopModule';
export { default as CityPopView } from './src/CityPopView';
export * from  './src/CityPop.types';
