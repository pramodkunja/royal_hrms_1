/** @type {import('tailwindcss').Config} */
module.exports = {
  purge: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./lib/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: false,
  theme: { extend: {} },
  variants: { extend: {} },
  plugins: [],
};
