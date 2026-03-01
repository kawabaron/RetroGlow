import CityPopProcessor from '@/modules/city-pop-processor';
import { Mood, useEditorStore } from '@/store/useEditorStore';
import Slider from '@react-native-community/slider';
import * as FileSystem from 'expo-file-system';
import * as MediaLibrary from 'expo-media-library';
import { useRouter } from 'expo-router';
import * as Sharing from 'expo-sharing';
import React, { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, Image, SafeAreaView, ScrollView, Text, TextInput, TouchableOpacity, View } from 'react-native';
import { IconChevronLeft, IconDeviceFloppy, IconDice5, IconShare } from 'tabler-icons-react-native';

const presetTitles = [
    "MIDNIGHT CRUISE", "NEON CITY", "TOKYO NIGHTS", "SUNSET DRIVE",
    "RETRO WAVE", "AFTER GLOW", "PLASTIC LOVE", "STAY WITH ME",
    "CITY POP", "NEON LIGHTS", "VAPORWAVE", "NIGHT CALL"
];

export default function EditorScreen() {
    const router = useRouter();
    const {
        inputUri, previewUri, isRenderingPreview, isRenderingFinal, params,
        setParams, setMood, setIsRenderingPreview, setIsRenderingFinal, setPreviewUri, setFinalUri
    } = useEditorStore();

    const [localTitle, setLocalTitle] = useState(params.title);

    const debounceTimeout = useRef<NodeJS.Timeout | null>(null);

    // Debounced preview render
    useEffect(() => {
        if (debounceTimeout.current) clearTimeout(debounceTimeout.current);

        // Skip if inputUri is empty (e.g. state reset)
        if (!inputUri) return;

        debounceTimeout.current = setTimeout(() => {
            renderPreview();
        }, 250);

        return () => {
            if (debounceTimeout.current) clearTimeout(debounceTimeout.current);
        };
    }, [params.mood, params.neon, params.tone, params.grain, params.title]);

    const renderPreview = async () => {
        if (!inputUri) return;
        setIsRenderingPreview(true);
        try {
            const outputUri = `${FileSystem.cacheDirectory}preview_${Date.now()}.jpg`;
            const result = await CityPopProcessor.process({
                inputUri,
                outputUri,
                mood: params.mood,
                neon: params.neon,
                tone: params.tone,
                grain: params.grain,
                title: params.title,
                targetWidth: 720,
                targetHeight: 1280,
                jpegQuality: 0.8
            });
            setPreviewUri(result.resultUri);
        } catch (error: any) {
            console.error(error);
            Alert.alert('Preview Error', error.message || 'Failed to render preview');
        } finally {
            setIsRenderingPreview(false);
        }
    };

    const renderFinal = async () => {
        if (!inputUri) return null;
        const outputUri = `${FileSystem.cacheDirectory}final_${Date.now()}.jpg`;
        const result = await CityPopProcessor.process({
            inputUri,
            outputUri,
            mood: params.mood,
            neon: params.neon,
            tone: params.tone,
            grain: params.grain,
            title: params.title,
            targetWidth: 1080,
            targetHeight: 1920,
            jpegQuality: 0.95
        });
        setFinalUri(result.resultUri);
        return result.resultUri;
    };

    const handleSave = async () => {
        setIsRenderingFinal(true);
        try {
            const finalResultUri = await renderFinal();
            if (finalResultUri) {
                const { status } = await MediaLibrary.requestPermissionsAsync();
                if (status === 'granted') {
                    await MediaLibrary.saveToLibraryAsync(finalResultUri);
                    Alert.alert('Success', '画像がカメラロールに保存されました');
                } else {
                    Alert.alert('Error', '保存には写真へのアクセス権限が必要です');
                }
            }
        } catch (error: any) {
            Alert.alert('Save Error', error.message || 'Failed to save image');
        } finally {
            setIsRenderingFinal(false);
        }
    };

    const handleShare = async () => {
        setIsRenderingFinal(true);
        try {
            const finalResultUri = await renderFinal();
            if (finalResultUri) {
                if (await Sharing.isAvailableAsync()) {
                    await Sharing.shareAsync(finalResultUri);
                } else {
                    Alert.alert('Error', 'このデバイスでは共有がサポートされていません');
                }
            }
        } catch (error: any) {
            Alert.alert('Share Error', error.message || 'Failed to share image');
        } finally {
            setIsRenderingFinal(false);
        }
    };

    const setRandomTitle = () => {
        const random = presetTitles[Math.floor(Math.random() * presetTitles.length)];
        setLocalTitle(random);
        setParams({ title: random });
    };

    const handleTitleChange = (text: string) => {
        // Allow alphanumerics and spaces, max 16 chars (validate)
        const filtered = text.replace(/[^a-zA-Z0-9 ]/g, '').slice(0, 16).toUpperCase();
        setLocalTitle(filtered);
        setParams({ title: filtered });
    };

    if (!inputUri) {
        return (
            <SafeAreaView className="flex-1 bg-black justify-center items-center">
                <Text className="text-white">画像が選択されていません</Text>
                <TouchableOpacity onPress={() => router.back()} className="mt-4 p-2 bg-white/20 rounded">
                    <Text className="text-white">戻る</Text>
                </TouchableOpacity>
            </SafeAreaView>
        );
    }

    return (
        <SafeAreaView className="flex-1 bg-black">
            <View className="flex-row items-center justify-between px-4 py-2 border-b border-gray-800">
                <TouchableOpacity onPress={() => router.back()} className="p-2 -ml-2">
                    <IconChevronLeft color="white" size={28} />
                </TouchableOpacity>
                <Text className="text-white font-bold text-lg tracking-widest text-shadow-glow">EDITOR</Text>
                <TouchableOpacity onPress={handleSave} className="p-2 -mr-2">
                    <IconDeviceFloppy color="white" size={28} />
                </TouchableOpacity>
            </View>

            <ScrollView className="flex-1" contentContainerStyle={{ paddingBottom: 40 }}>
                {/* Preview Area (Always 9:16 aspect ratio) */}
                <View className="w-full items-center py-6">
                    <View className="relative w-[70vw] aspect-[9/16] bg-gray-900 rounded-lg overflow-hidden border border-white/10">
                        <Image
                            source={{ uri: previewUri || inputUri }}
                            className="absolute inset-0 w-full h-full"
                            resizeMode="cover"
                        />
                        {isRenderingPreview && (
                            <View className="absolute inset-0 bg-black/40 justify-center items-center">
                                <ActivityIndicator size="large" color="#FF007F" />
                            </View>
                        )}

                        {/* Title Overlay in JS (mock layout for visual feedback if needed, 
                but MVP says Native Module bakes it. We could show it in JS if preview is slow,
                but per MVP let's let Native do it. For MVP, we can rely on Native preview output. */}
                    </View>
                </View>

                {/* Controls */}
                <View className="px-6 space-y-6">

                    {/* Mood Selector */}
                    <View>
                        <Text className="text-gray-400 text-xs font-bold mb-3 uppercase tracking-wider">Mood Preset</Text>
                        <View className="flex-row justify-between">
                            {(['nightDrive', 'sunsetNeon', 'afterglow'] as Mood[]).map(m => (
                                <TouchableOpacity
                                    key={m}
                                    onPress={() => setMood(m)}
                                    className={`flex-1 mx-1 py-3 rounded border ${params.mood === m ? 'border-[#FF007F] bg-[#FF007F]/20' : 'border-gray-700 bg-gray-900'}`}
                                >
                                    <Text className={`text-center text-xs font-bold ${params.mood === m ? 'text-white' : 'text-gray-400'}`}>
                                        {m === 'nightDrive' ? 'NIGHT' : m === 'sunsetNeon' ? 'SUNSET' : 'AFTERGLOW'}
                                    </Text>
                                </TouchableOpacity>
                            ))}
                        </View>
                    </View>

                    {/* Sliders */}
                    <View className="w-full mt-4">
                        <View className="mb-4">
                            <View className="flex-row justify-between">
                                <Text className="text-white text-sm font-semibold">Neon</Text>
                                <Text className="text-gray-500 text-xs">{Math.round(params.neon * 100)}</Text>
                            </View>
                            <Slider
                                style={{ width: '100%', height: 40 }}
                                minimumValue={0}
                                maximumValue={1}
                                value={params.neon}
                                onValueChange={v => setParams({ neon: v })}
                                minimumTrackTintColor="#FF007F"
                                maximumTrackTintColor="#333333"
                                thumbTintColor="#FFFFFF"
                            />
                        </View>

                        <View className="mb-4">
                            <View className="flex-row justify-between">
                                <Text className="text-white text-sm font-semibold">Tone</Text>
                                <Text className="text-gray-500 text-xs">{Math.round(params.tone * 100)}</Text>
                            </View>
                            <Slider
                                style={{ width: '100%', height: 40 }}
                                minimumValue={0}
                                maximumValue={1}
                                value={params.tone}
                                onValueChange={v => setParams({ tone: v })}
                                minimumTrackTintColor="#FF5E00"
                                maximumTrackTintColor="#333333"
                                thumbTintColor="#FFFFFF"
                            />
                        </View>

                        <View className="mb-4">
                            <View className="flex-row justify-between">
                                <Text className="text-white text-sm font-semibold">Grain</Text>
                                <Text className="text-gray-500 text-xs">{Math.round(params.grain * 100)}</Text>
                            </View>
                            <Slider
                                style={{ width: '100%', height: 40 }}
                                minimumValue={0}
                                maximumValue={1}
                                value={params.grain}
                                onValueChange={v => setParams({ grain: v })}
                                minimumTrackTintColor="#9D00FF"
                                maximumTrackTintColor="#333333"
                                thumbTintColor="#FFFFFF"
                            />
                        </View>
                    </View>

                    {/* Title Input */}
                    <View className="mt-2">
                        <Text className="text-gray-400 text-xs font-bold mb-2 uppercase tracking-wider">Title (Max 16 chars)</Text>
                        <View className="flex-row items-center border border-gray-700 bg-gray-900 rounded-lg px-4 py-2">
                            <TextInput
                                value={localTitle}
                                onChangeText={handleTitleChange}
                                placeholder="ENTER TITLE"
                                placeholderTextColor="#666"
                                maxLength={16}
                                className="flex-1 text-white font-bold text-lg tracking-widest h-10"
                            />
                            <TouchableOpacity onPress={setRandomTitle} className="ml-2 bg-gray-800 p-2 rounded-full">
                                <IconDice5 color="#FF007F" size={24} />
                            </TouchableOpacity>
                        </View>
                    </View>

                    {/* Actions */}
                    <View className="flex-row mt-6 pt-4 border-t border-gray-800">
                        <TouchableOpacity
                            className="flex-1 bg-white p-4 rounded-xl flex-row justify-center items-center active:bg-gray-200 mr-2"
                            onPress={handleSave}
                            disabled={isRenderingFinal}
                        >
                            <IconDeviceFloppy color="black" size={20} />
                            <Text className="text-black font-bold ml-2">SAVE</Text>
                        </TouchableOpacity>
                        <TouchableOpacity
                            className="flex-1 bg-gray-800 p-4 rounded-xl flex-row justify-center items-center active:bg-gray-700 ml-2"
                            onPress={handleShare}
                            disabled={isRenderingFinal}
                        >
                            <IconShare color="white" size={20} />
                            <Text className="text-white font-bold ml-2">SHARE</Text>
                        </TouchableOpacity>
                    </View>

                </View>
            </ScrollView>
        </SafeAreaView>
    );
}
