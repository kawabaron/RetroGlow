import { NativeModule, requireNativeModule } from 'expo';

export type ProcessArgs = {
    inputUri: string;
    outputUri: string;
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

export default requireNativeModule<CityPopProcessorModule>('CityPopProcessor');
