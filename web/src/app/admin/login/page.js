"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { collection, query, where, getDocs } from "firebase/firestore";
import { db } from "../../../lib/firebase";
import CryptoJS from "crypto-js";
import { Shield, Mail, Lock } from "lucide-react";

export default function AdminLogin() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    try {
      const q = query(collection(db, "hospitals"), where("email", "==", email));
      const querySnapshot = await getDocs(q);

      if (querySnapshot.empty) {
        setError("Invalid email or password");
        setLoading(false);
        return;
      }

      const hospitalDoc = querySnapshot.docs[0];
      const hospitalData = hospitalDoc.data();
      const hashedPassword = CryptoJS.SHA256(password).toString();

      if (hospitalData.passwordHash === hashedPassword) {
        // Safe to use localStorage in this client component
        localStorage.setItem("hospitalId", hospitalDoc.id);
        router.push("/admin/hospitaldashboard");
      } else {
        setError("Invalid email or password");
      }
    } catch (err) {
      console.error(err);
      setError("An error occurred during login. Please try again.");
    }

    setLoading(false);
  };

  return (
    <div className="min-h-screen bg-[#050505] flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-[#0A0A0C] border border-[#1E1E24] rounded-2xl p-8 shadow-2xl">
        <div className="flex justify-center mb-6">
          <div className="w-16 h-16 bg-[#E11D48]/10 rounded-full flex items-center justify-center border border-[#E11D48]/30">
            <Shield className="w-8 h-8 text-[#E11D48]" />
          </div>
        </div>
        <h2 className="text-2xl font-bold text-center text-white mb-2">
          Hospital Admin Portal
        </h2>
        <p className="text-center text-gray-400 mb-8">
          Secure access to emergency blood dispatches
        </p>

        {error && (
          <div className="bg-red-500/10 border border-red-500/50 text-red-500 px-4 py-3 rounded-lg mb-6 text-sm">
            {error}
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">
              Email Address
            </label>
            <div className="relative">
              <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full bg-[#121214] border border-[#2A2A35] rounded-xl py-3 pl-10 pr-4 text-white focus:outline-none focus:border-[#E11D48] transition-colors"
                placeholder="admin@hospital.com"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2">
              Password
            </label>
            <div className="relative">
              <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full bg-[#121214] border border-[#2A2A35] rounded-xl py-3 pl-10 pr-4 text-white focus:outline-none focus:border-[#E11D48] transition-colors"
                placeholder="••••••••"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-[#E11D48] hover:bg-[#BE123C] text-white font-bold py-3 px-4 rounded-xl transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? "Authenticating..." : "Sign In"}
          </button>
        </form>

        <div className="mt-6 text-center">
          <p className="text-sm text-gray-400">
            Don&apos;t have a hospital account?{" "}
            <button
              onClick={() => router.push("/admin/register")}
              className="text-[#E11D48] hover:underline"
            >
              Register here
            </button>
          </p>
        </div>
      </div>
    </div>
  );
}
