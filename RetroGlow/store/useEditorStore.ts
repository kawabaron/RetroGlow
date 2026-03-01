import { create } from 'zustand';

export type Mood = "nightDrive" | "sunsetNeon" | "afterglow";

export type Params = {
    mood: Mood;
    neon: number; // 0..1
    tone: number; // 0..1
    grain: number; // 0..1
    title: string; // max 16 chars
};

export type EditorState = {
    inputUri: string;
    previewUri: string | null;
    finalUri: string | null;
    isRenderingPreview: boolean;
    isRenderingFinal: boolean;
    lastError: string | null;
    params: Params;
    setInputUri: (uri: string) => void;
    setPreviewUri: (uri: string | null) => void;
    setFinalUri: (uri: string | null) => void;
    setIsRenderingPreview: (isRendering: boolean) => void;
    setIsRenderingFinal: (isRendering: boolean) => void;
    setLastError: (error: string | null) => void;
    setParams: (params: Partial<Params>) => void;
    setMood: (mood: Mood) => void;
    reset: () => void;
};

const defaultParams: Params = {
    mood: 'nightDrive',
    neon: 0.55,
    tone: 0.65,
    grain: 0.25,
    title: '',
};

export const useEditorStore = create<EditorState>((set) => ({
    inputUri: '',
    previewUri: null,
    finalUri: null,
    isRenderingPreview: false,
    isRenderingFinal: false,
    lastError: null,
    params: { ...defaultParams },

    setInputUri: (uri) => set({ inputUri: uri }),
    setPreviewUri: (uri) => set({ previewUri: uri }),
    setFinalUri: (uri) => set({ finalUri: uri }),
    setIsRenderingPreview: (isRendering) => set({ isRenderingPreview: isRendering }),
    setIsRenderingFinal: (isRendering) => set({ isRenderingFinal: isRendering }),
    setLastError: (error) => set({ lastError: error }),

    setParams: (newParams) => set((state) => ({
        params: { ...state.params, ...newParams }
    })),

    setMood: (mood) => set((state) => {
        let preset = { neon: 0.55, tone: 0.65, grain: 0.25 };
        if (mood === 'sunsetNeon') preset = { neon: 0.45, tone: 0.45, grain: 0.20 };
        else if (mood === 'afterglow') preset = { neon: 0.35, tone: 0.35, grain: 0.30 };

        return {
            params: { ...state.params, mood, ...preset }
        };
    }),

    reset: () => set({
        inputUri: '',
        previewUri: null,
        finalUri: null,
        isRenderingPreview: false,
        isRenderingFinal: false,
        lastError: null,
        params: { ...defaultParams }
    }),
}));
