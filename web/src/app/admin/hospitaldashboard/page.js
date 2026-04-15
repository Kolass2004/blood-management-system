"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { collection, doc, getDoc, getDocs, addDoc, serverTimestamp, deleteDoc } from "firebase/firestore";
import { db } from "../../../lib/firebase";
import { Plus, Users, Droplets, Phone, User, Activity, ArrowRight, LogOut, Loader2, Trash2 } from "lucide-react";

export default function HospitalDashboard() {
  const router = useRouter();
  const [hospitalId, setHospitalId] = useState(null);
  const [hospitalInfo, setHospitalInfo] = useState(null);
  const [patients, setPatients] = useState([]);
  const [loading, setLoading] = useState(true);
  
  // Modal State
  const [showModal, setShowModal] = useState(false);
  const [newPatient, setNewPatient] = useState({
    name: "",
    age: "",
    bloodGroup: "A+",
    nomineeName: "",
    contact: "",
    conditions: "",
  });

  const bloodGroups = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"];

  async function fetchPatients(hid) {
    try {
      const pSnapshot = await getDocs(collection(db, `hospitals/${hid}/patients`));
      const pData = [];
      pSnapshot.forEach((doc) => {
        pData.push({ id: doc.id, ...doc.data() });
      });
      // Sort by creation time if exists (newest first)
      pData.sort((a, b) => (b.createdAt?.toMillis() || Date.now()) - (a.createdAt?.toMillis() || Date.now()));
      setPatients(pData);
      setLoading(false);
    } catch (error) {
      console.error(error);
      setLoading(false);
    }
  }

  useEffect(() => {
    const checkSession = async () => {
      const storedId = localStorage.getItem("hospitalId");
      if (!storedId) {
        router.push("/admin/login");
        return;
      }
      setHospitalId(storedId);
      
      // Fetch hospital details
      const hDoc = await getDoc(doc(db, "hospitals", storedId));
      if (hDoc.exists()) setHospitalInfo(hDoc.data());

      // Fetch patients
      fetchPatients(storedId);
    };

    checkSession();
  }, [router]);

  const handleAddPatient = async (e) => {
    e.preventDefault();
    if (!hospitalId) return;

    try {
      await addDoc(collection(db, `hospitals/${hospitalId}/patients`), {
        ...newPatient,
        age: parseInt(newPatient.age),
        createdAt: serverTimestamp(),
      });
      setShowModal(false);
      setNewPatient({ name: "", age: "", bloodGroup: "A+", nomineeName: "", contact: "", conditions: "" });
      fetchPatients(hospitalId); // refresh
    } catch (err) {
      console.error(err);
      alert("Failed to add patient.");
    }
  };

  const handleLogout = () => {
    localStorage.removeItem("hospitalId");
    router.push("/admin/login");
  };

  const handleDeletePatient = async (patientId) => {
    const confirmDelete = window.confirm("Are you sure you want to permanently remove this patient record?");
    if (!confirmDelete) return;

    try {
      await deleteDoc(doc(db, `hospitals/${hospitalId}/patients`, patientId));
      setPatients(prev => prev.filter(p => p.id !== patientId));
    } catch (err) {
      console.error("Error deleting patient:", err);
      alert("Failed to delete patient record.");
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-[#050505] flex items-center justify-center">
        <Loader2 className="w-10 h-10 text-[#E11D48] animate-spin" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#050505] text-white">
      {/* Navbar */}
      <header className="border-b border-[#1E1E24] bg-[#0A0A0C] sticky top-0 z-10 w-full px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-[#E11D48]/10 rounded-full flex items-center justify-center border border-[#E11D48]/30">
            <Activity className="w-5 h-5 text-[#E11D48]" />
          </div>
          <div>
            <h1 className="text-xl font-bold">{hospitalInfo?.name || "Hospital Dashboard"}</h1>
            <p className="text-xs text-gray-400">{hospitalInfo?.email}</p>
          </div>
        </div>
        <button 
          onClick={handleLogout}
          className="flex items-center gap-2 text-gray-400 hover:text-white transition-colors text-sm px-3 py-2 rounded-lg hover:bg-[#1E1E24]"
        >
          <LogOut className="w-4 h-4" />
          Logout
        </button>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto p-6 md:p-10">
        <div className="flex flex-col md:flex-row md:items-center justify-between mb-8 gap-4">
          <div>
            <h2 className="text-3xl font-bold mb-1">Active Patients</h2>
            <p className="text-gray-400">Manage individuals requiring emergency blood transfusions.</p>
          </div>
          
          <button 
            onClick={() => setShowModal(true)}
            className="flex items-center justify-center gap-2 bg-[#E11D48] hover:bg-[#BE123C] text-white px-5 py-3 rounded-xl font-semibold transition-colors shadow-lg shadow-[#E11D48]/20"
          >
            <Plus className="w-5 h-5" />
            New Patient
          </button>
        </div>

        {/* Patient Grid */}
        {patients.length === 0 ? (
          <div className="bg-[#0A0A0C] border border-[#1E1E24] rounded-2xl p-12 flex flex-col items-center justify-center text-center">
            <Users className="w-16 h-16 text-gray-600 mb-4" />
            <h3 className="text-xl font-bold text-gray-300 mb-2">No Active Patients</h3>
            <p className="text-gray-500 max-w-sm">There are currently no patients registered for blood requirements. Click &quot;New Patient&quot; to add one.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {patients.map(patient => (
              <div key={patient.id} className="bg-[#0A0A0C] border border-[#1E1E24] rounded-2xl p-6 hover:border-[#E11D48]/50 transition-colors group flex flex-col h-full">
                <div className="flex justify-between items-start mb-4">
                  <div>
                    <h3 className="text-xl font-bold text-white mb-1 group-hover:text-[#E11D48] transition-colors flex items-center gap-2">
                      {patient.name}
                      <button 
                        onClick={() => handleDeletePatient(patient.id)} 
                        className="text-gray-600 hover:text-[#E11D48] transition-colors p-1"
                        title="Delete Patient"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </h3>
                    <p className="text-sm text-gray-400">{patient.age} years old</p>
                  </div>
                  <div className="bg-[#E11D48]/10 border border-[#E11D48]/30 text-[#E11D48] font-bold px-3 py-1.5 rounded-lg flex items-center gap-1.5">
                    <Droplets className="w-4 h-4" />
                    {patient.bloodGroup}
                  </div>
                </div>
                
                <div className="flex-1 space-y-3 mb-6">
                  {patient.conditions && (
                    <div className="flex items-start text-sm text-gray-300 bg-[#121214] p-3 rounded-lg border border-[#1e1e24]">
                      <Activity className="w-4 h-4 text-gray-500 mr-3 mt-0.5" />
                      <div>
                        <p className="text-xs text-gray-500">Conditions</p>
                        <p className="line-clamp-2 text-gray-300">{patient.conditions}</p>
                      </div>
                    </div>
                  )}
                  <div className="flex items-center text-sm text-gray-300 bg-[#121214] p-3 rounded-lg border border-[#1e1e24]">
                    <User className="w-4 h-4 text-gray-500 mr-3" />
                    <div>
                      <p className="text-xs text-gray-500">Nominee</p>
                      <p>{patient.nomineeName}</p>
                    </div>
                  </div>
                  <div className="flex items-center text-sm text-gray-300 bg-[#121214] p-3 rounded-lg border border-[#1e1e24]">
                    <Phone className="w-4 h-4 text-gray-500 mr-3" />
                    <div>
                      <p className="text-xs text-gray-500">Contact</p>
                      <p>{patient.contact}</p>
                    </div>
                  </div>
                </div>

                <button 
                  onClick={() => router.push(`/admin/hospitaldashboard/requests?patientId=${patient.id}`)}
                  className="w-full flex items-center justify-center gap-2 bg-[#1A1A20] hover:bg-[#E11D48] text-white border border-[#2A2A35] hover:border-[#E11D48] py-3 px-4 rounded-xl font-semibold transition-all group/btn"
                >
                  <Activity className="w-4 h-4" />
                  Request Blood
                  <ArrowRight className="w-4 h-4 ml-1 opacity-0 group-hover/btn:opacity-100 transition-opacity translate-x-[-10px] group-hover/btn:translate-x-0" />
                </button>
              </div>
            ))}
          </div>
        )}
      </main>

      {/* New Patient Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-[#0A0A0C] border border-[#1E1E24] rounded-2xl w-full max-w-md shadow-2xl relative">
            <button 
              onClick={() => setShowModal(false)}
              className="absolute top-4 right-4 text-gray-400 hover:text-white"
            >
              ✕
            </button>
            <div className="p-8">
              <h2 className="text-2xl font-bold mb-6 flex items-center gap-2">
                <Users className="text-[#E11D48]" />
                Add Patient
              </h2>
              
              <form onSubmit={handleAddPatient} className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-gray-400 mb-1 uppercase tracking-wider">Patient Name</label>
                  <input required type="text" value={newPatient.name} onChange={e => setNewPatient({...newPatient, name: e.target.value})} className="w-full bg-[#121214] border border-[#2A2A35] rounded-xl p-3 text-white focus:outline-none focus:border-[#E11D48]" placeholder="John Doe" />
                </div>
                
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-medium text-gray-400 mb-1 uppercase tracking-wider">Age</label>
                    <input required type="number" min="1" max="120" value={newPatient.age} onChange={e => setNewPatient({...newPatient, age: e.target.value})} className="w-full bg-[#121214] border border-[#2A2A35] rounded-xl p-3 text-white focus:outline-none focus:border-[#E11D48]" placeholder="45" />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-gray-400 mb-1 uppercase tracking-wider">Blood Required</label>
                    <select value={newPatient.bloodGroup} onChange={e => setNewPatient({...newPatient, bloodGroup: e.target.value})} className="w-full bg-[#121214] border border-[#2A2A35] rounded-xl p-3 text-white focus:outline-none focus:border-[#E11D48] appearance-none">
                      {bloodGroups.map(bg => <option key={bg} value={bg}>{bg}</option>)}
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-medium text-gray-400 mb-1 uppercase tracking-wider">Nominee Name</label>
                  <input required type="text" value={newPatient.nomineeName} onChange={e => setNewPatient({...newPatient, nomineeName: e.target.value})} className="w-full bg-[#121214] border border-[#2A2A35] rounded-xl p-3 text-white focus:outline-none focus:border-[#E11D48]" placeholder="Jane Doe" />
                </div>

                <div>
                  <label className="block text-xs font-medium text-gray-400 mb-1 uppercase tracking-wider">Contact Number</label>
                  <input required type="tel" value={newPatient.contact} onChange={e => setNewPatient({...newPatient, contact: e.target.value})} className="w-full bg-[#121214] border border-[#2A2A35] rounded-xl p-3 text-white focus:outline-none focus:border-[#E11D48]" placeholder="+91 9876543210" />
                </div>

                <div>
                  <label className="block text-xs font-medium text-gray-400 mb-1 uppercase tracking-wider">Patient Conditions</label>
                  <textarea required rows="3" value={newPatient.conditions} onChange={e => setNewPatient({...newPatient, conditions: e.target.value})} className="w-full bg-[#121214] border border-[#2A2A35] rounded-xl p-3 text-white focus:outline-none focus:border-[#E11D48] resize-none" placeholder="E.g., Dengue fever, Surgery requirement..."></textarea>
                </div>

                <div className="pt-4">
                  <button type="submit" className="w-full bg-[#E11D48] hover:bg-[#BE123C] text-white font-bold py-3 px-4 rounded-xl transition-colors">
                    Save Patient Record
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
