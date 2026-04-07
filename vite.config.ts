import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import path from "path";

// https://vitejs.dev/config/
export default defineConfig(() => ({
  base: "/",
  server: {
    host: "::",
    port: 8080,
    cors: {
      origin: process.env.VITE_CORS_ALLOWED_ORIGINS
        ? process.env.VITE_CORS_ALLOWED_ORIGINS.split(",").map((o) => o.trim()).filter(Boolean)
        : ["http://localhost:5173"],
    },
    hmr: {
      overlay: false,
    },
  },
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
    dedupe: ["react", "react-dom"],
  },
  build: {
    chunkSizeWarningLimit: 1000,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ["react", "react-dom", "@tanstack/react-query"],
          ui: ["@/components/ui/button", "@/components/ui/card", "@/components/ui/dialog"],
        },
      },
    },
  },
}));
