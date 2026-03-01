/** @type {import('tailwindcss').Config} */
module.exports = {
    content: ["./app/**/*.{js,jsx,ts,tsx}", "./components/**/*.{js,jsx,ts,tsx}"],
    presets: [require("nativewind/preset")],
    theme: {
        extend: {
            colors: {
                glowNeon: "#FF007F",
                glowSunset: "#FF5E00",
                glowAfterglow: "#9D00FF",
            }
        },
    },
    plugins: [],
}
