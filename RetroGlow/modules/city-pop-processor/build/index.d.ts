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
declare const _default: any;
export default _default;
