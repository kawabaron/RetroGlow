import { useEditorStore } from '@/store/useEditorStore';
import * as ImagePicker from 'expo-image-picker';
import { useRouter } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { Alert, SafeAreaView, Text, TouchableOpacity, View } from 'react-native';
import { IconCamera, IconPhoto } from 'tabler-icons-react-native';

export default function HomeScreen() {
    const router = useRouter();
    const { setInputUri, reset } = useEditorStore();

    const handlePickImage = async () => {
        let result = await ImagePicker.launchImageLibraryAsync({
            mediaTypes: ['images'],
            quality: 1,
        });

        if (!result.canceled && result.assets && result.assets.length > 0) {
            reset();
            setInputUri(result.assets[0].uri);
            router.push('/editor');
        }
    };

    const handleTakePhoto = async () => {
        const permissionResult = await ImagePicker.requestCameraPermissionsAsync();

        if (permissionResult.granted === false) {
            Alert.alert("カメラへのアクセスが必要です");
            return;
        }

        let result = await ImagePicker.launchCameraAsync({
            quality: 1,
        });

        if (!result.canceled && result.assets && result.assets.length > 0) {
            reset();
            setInputUri(result.assets[0].uri);
            router.push('/editor');
        }
    };

    return (
        <SafeAreaView className="flex-1 bg-black justify-center items-center px-6">
            <StatusBar style="light" />
            <View className="mb-12 items-center">
                <Text className="text-4xl font-bold text-white tracking-widest text-shadow-glow">RetroGlow</Text>
                <Text className="text-gray-400 mt-2 text-center text-sm">
                    あなたの写真をシティポップ風のストーリーに
                </Text>
            </View>

            <View className="w-full space-y-4">
                <TouchableOpacity
                    className="bg-white/10 p-4 rounded-2xl flex-row items-center justify-center border border-white/20 active:bg-white/20"
                    onPress={handlePickImage}
                >
                    <IconPhoto color="white" size={24} />
                    <Text className="text-white text-lg font-semibold ml-3">ライブラリから選ぶ</Text>
                </TouchableOpacity>

                <TouchableOpacity
                    className="bg-white/10 p-4 rounded-2xl flex-row items-center justify-center border border-white/20 active:bg-white/20 mt-4"
                    onPress={handleTakePhoto}
                >
                    <IconCamera color="white" size={24} />
                    <Text className="text-white text-lg font-semibold ml-3">カメラで撮る</Text>
                </TouchableOpacity>
            </View>

            <Text className="text-gray-500 text-xs mt-8 text-center">
                ※写真は端末内で処理されます（アップロードなし）
            </Text>
        </SafeAreaView>
    );
}
