import { NativeModule } from 'expo';
export type ProcessArgs = {
    inputUri: string;
    mood: "nightDrive" | "sunsetNeon" | "afterglow";
    neon: number;
    tone: number;
    grain: number;
    title: string;
    targetWidth: number;
    targetHeight: number;
    jpegQuality: number;
};
export type ProcessResult = {
    resultUri: string;
    width: number;
    height: number;
};
declare class CityPopProcessorModule extends NativeModule {
    process(args: ProcessArgs): Promise<ProcessResult>;
}
declare const _default: CityPopProcessorModule;
export default _default;
