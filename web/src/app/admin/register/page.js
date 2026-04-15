"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { collection, addDoc, serverTimestamp } from "firebase/firestore";
import { db } from "../../../lib/firebase";
import CryptoJS from "crypto-js";
import dynamic from "next/dynamic";
import { Shield, Building, MapPin, Mail, Lock } from "lucide-react";

// Dynamically import MapPicker so it doesn't break SSR
const MapPicker = dynamic(() => import("../../../components/MapPicker"), { ssr: false });

export default function AdminRegister() {
  const router = useRouter();
  const [formData, setFormData] = useState({
    hospitalName: "",
    address: "",
    email: "",
    password: "",
  });
  const [location, setLocation] = useState({ lat: 13.0827, lng: 80.2707 }); // Default Chennai
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleRegister = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    try {
      const passwordHash = CryptoJS.SHA256(formData.password).toString();
      
      const docRef = await addDoc(collection(db, "hospitals"), {
        name: formData.hospitalName,
        address: formData.address,
        email: formData.email,
        passwordHash,
        location: {
          lat: location.lat,
          lng: location.lng,
        },
        createdAt: serverTimestamp(),
      });

      // Save to local storage
      localStorage.setItem("hospitalId", docRef.id);
      router.push("/admin/hospitaldashboard");

    } catch (err) {
      console.error("Error registering hospital: ", err);
      setError("Registration failed. Please try again.");
    }

    setLoading(false);
  };

  return (
    <div className="min-h-screen bg-[#050505] flex items-center justify-center p-4 py-12">
      <div className="max-w-4xl w-full flex flex-col md:flex-row bg-[#0A0A0C] border border-[#1E1E24] rounded-2xl shadow-2xl overflow-hidden">
        
        {/* Left Side - Details */}
        <div className="flex-1 p-8 md:p-10 border-r border-[#1E1E24]">
          <div className="flex items-center gap-4 mb-8">
            <div className="w-12 h-12 bg-[#E11D48]/10 rounded-full flex items-center justify-center border border-[#E11D48]/30">
              <Shield className="w-6 h-6 text-[#E11D48]" />
            </div>
            <div>
              <h2 className="text-2xl font-bold text-white">Register Hospital</h2>
              <p className="text-sm text-gray-400">Join the emergency dispatch network</p>
            </div>
          </div>

          {error && (
            <div className="bg-red-500/10 border border-red-500/50 text-red-500 px-4 py-3 rounded-lg mb-6 text-sm">
              {error}
            </div>
          )}

          <form onSubmit={handleRegister} className="space-y-5">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">Hospital Name</label>
              <div className="relative">
                <Building className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                <input
                  type="text"
                  required
                  value={formData.hospitalName}
                  onChange={(e) => setFormData({...formData, hospitalName: e.target.value})}
                  className="w-full bg-[#121214] border border-[#2A2A35] rounded-xl py-3 pl-10 pr-4 text-white focus:outline-none focus:border-[#E11D48] transition-colors"
                  placeholder="e.g. City General Hospital"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-400 mb-1">Full Address</label>
              <div className="relative">
                <MapPin className="absolute left-3 top-3 w-5 h-5 text-gray-500" />
                <textarea
                  required
                  rows="2"
                  value={formData.address}
                  onChange={(e) => setFormData({...formData, address: e.target.value})}
                  className="w-full bg-[#121214] border border-[#2A2A35] rounded-xl py-3 pl-10 pr-4 text-white focus:outline-none focus:border-[#E11D48] transition-colors"
                  placeholder="Street, City, Postal Code"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-1">Admin Email</label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                  <input
                    type="email"
                    required
                    value={formData.email}
                    onChange={(e) => setFormData({...formData, email: e.target.value})}
                    className="w-full bg-[#121214] border border-[#2A2A35] rounded-xl py-3 pl-10 pr-4 text-white focus:outline-none focus:border-[#E11D48] transition-colors"
                    placeholder="admin@hospital.com"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-1">Password</label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                  <input
                    type="password"
                    required
                    value={formData.password}
                    onChange={(e) => setFormData({...formData, password: e.target.value})}
                    // minLength={6}
                    className="w-full bg-[#121214] border border-[#2A2A35] rounded-xl py-3 pl-10 pr-4 text-white focus:outline-none focus:border-[#E11D48] transition-colors"
                    placeholder="••••••••"
                  />
                </div>
              </div>
            </div>

            <div className="pt-2">
              <button
                type="submit"
                disabled={loading}
                className="w-full bg-[#E11D48] hover:bg-[#BE123C] text-white font-bold py-3 px-4 rounded-xl transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {loading ? "Registering..." : "Complete Registration"}
              </button>
            </div>
            
            <div className="text-center pt-2">
              <p className="text-sm text-gray-400">
                Already registered?{" "}
                <button
                  type="button"
                  onClick={() => router.push("/admin/login")}
                  className="text-[#E11D48] hover:underline"
                >
                  Sign in here
                </button>
              </p>
            </div>
          </form>
        </div>

        {/* Right Side - Map */}
        <div className="flex-1 bg-[#121214] p-6 flex flex-col">
          <label className="block text-sm font-bold text-gray-300 mb-3 uppercase tracking-wider">
            Pinpoint Exact Location
          </label>
          <div className="flex-1 rounded-xl overflow-hidden border border-[#2A2A35] relative min-h-[300px]">
             <MapPicker 
                defaultLat={location.lat}
                defaultLng={location.lng}
                onLocationSelect={(lat, lng) => setLocation({ lat, lng })}
             />
             <div className="absolute bottom-4 left-4 right-4 bg-[#0A0A0C]/90 backdrop-blur-sm border border-[#2A2A35] p-3 rounded-xl z-[1000] pointer-events-none">
                <p className="text-xs text-gray-400 text-center">
                  Selected Coordinates: <span className="text-white font-mono">{location.lat.toFixed(4)}, {location.lng.toFixed(4)}</span>
                </p>
             </div>
          </div>
        </div>

      </div>
    </div>
  );
}
