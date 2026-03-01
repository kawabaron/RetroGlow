import { requireNativeModule } from 'expo-modules-core';

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

export default requireNativeModule('CityPopProcessor');
