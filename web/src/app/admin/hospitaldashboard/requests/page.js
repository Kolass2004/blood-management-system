"use client";

import { useEffect, useState, Suspense } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { collection, doc, getDoc, getDocs, setDoc, onSnapshot } from "firebase/firestore";
import { db } from "../../../../lib/firebase";
import dynamic from "next/dynamic";
import { MapPin, User, Droplets, Phone, Activity, ArrowLeft, Send, CheckCircle2 } from "lucide-react";

const MapDisplay = dynamic(() => import("../../../../components/MapDisplay"), { ssr: false });

function getDistanceFromLatLonInKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius of the earth in km
  const dLat = deg2rad(lat2 - lat1);
  const dLon = deg2rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; // Distance in km
}

function deg2rad(deg) {
  return deg * (Math.PI / 180);
}

function RequestsContent() {
  const searchParams = useSearchParams();
  const patientId = searchParams.get("patientId");
  const router = useRouter();

  const [hospitalId, setHospitalId] = useState(null);
  const [hospitalInfo, setHospitalInfo] = useState(null);
  const [patientInfo, setPatientInfo] = useState(null);
  const [eligibleDonors, setEligibleDonors] = useState([]);
  const [requestSent, setRequestSent] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const init = async () => {
      const hid = localStorage.getItem("hospitalId");
      if (!hid) return router.push("/admin/login");
      setHospitalId(hid);

      try {
        // Fetch Hospital
        const hDoc = await getDoc(doc(db, "hospitals", hid));
        if (!hDoc.exists()) return;
        const hData = hDoc.data();
        setHospitalInfo(hData);

        // Fetch Patient
        if (!patientId) return;
        const pDoc = await getDoc(doc(db, `hospitals/${hid}/patients`, patientId));
        if (!pDoc.exists()) return;
        const pData = pDoc.data();
        setPatientInfo(pData);

        // Fetch ALL Donors to filter
        const usersSnap = await getDocs(collection(db, "users"));
        const matchedDonors = [];

        usersSnap.forEach((doc) => {
          const user = doc.data();
          // Filter by Blood Group and valid Location
          if (user.bloodGroup === pData.bloodGroup && user.location && user.isRegistrationComplete !== false) {
            const distance = getDistanceFromLatLonInKm(
              hData.location.lat,
              hData.location.lng,
              user.location.lat,
              user.location.lng
            );

            // Match within 30 KM
            if (distance <= 30) {
              matchedDonors.push({
                id: doc.id,
                ...user,
                distance,
                status: "ready"
              });
            }
          }
        });

        // Sort by closest first
        matchedDonors.sort((a, b) => a.distance - b.distance);
        setEligibleDonors(matchedDonors);
        setLoading(false);

      } catch (err) {
        console.error(err);
        setLoading(false);
      }
    };

    init();
  }, [patientId, router]);

  const handleSendRequests = async () => {
    if (eligibleDonors.length === 0) return;
    
    // eslint-disable-next-line react-hooks/purity
    const bulkRequestId = Date.now().toString();

    const updatedDonors = [...eligibleDonors].map(d => ({...d, status: "pending"}));
    setEligibleDonors(updatedDonors);
    setRequestSent(true);

    // Send individual request docs to all eligible donors' inboxes
    for (const donor of updatedDonors) {
      try {
        const reqPath = `users/${donor.id}/requests`;
        await setDoc(doc(db, reqPath, bulkRequestId), {
          // eslint-disable-next-line react-hooks/purity
          timestamp: Date.now(),
          hospitalLat: parseFloat(hospitalInfo.location.lat),
          hospitalLng: parseFloat(hospitalInfo.location.lng),
          bloodType: patientInfo.bloodGroup,
          message: `URGENT: ${hospitalInfo.name} requires ${patientInfo.bloodGroup} blood for a ${patientInfo.age}y old patient. You are ${donor.distance.toFixed(1)}km away. Can you help?`,
          status: "pending"
        });

        // Set up real-time listener to track acknowledgement
        setupDonorListener(donor.id, bulkRequestId);
      } catch (err) {
        console.error(`Error sending request to ${donor.id}:`, err);
      }
    }
  };

  const setupDonorListener = (donorId, requestId) => {
    const unsub = onSnapshot(doc(db, `users/${donorId}/requests/${requestId}`), (docSnap) => {
      if (docSnap.exists()) {
        const currentData = docSnap.data();
        if (currentData.status === "acknowledged") {
          // Update sidebar array
          setEligibleDonors(prev => prev.map(d => 
            d.id === donorId ? { ...d, status: "acknowledged" } : d
          ));
        }
      }
    });

    // We keep these listeners active globally for this view so state updates automatically
  };


  if (loading) return <div className="min-h-screen bg-[#050505] flex items-center justify-center p-4">Loading match algorithm...</div>

  return (
    <div className="min-h-screen bg-[#050505] text-white flex flex-col md:flex-row">
      
      {/* Left Main Section */}
      <div className="flex-1 flex flex-col h-screen overflow-hidden">
        {/* Header */}
        <header className="border-b border-[#1E1E24] bg-[#0A0A0C] px-6 py-4 flex items-center justify-between z-10 shrink-0">
          <div className="flex items-center gap-4">
            <button onClick={() => router.push("/admin/hospitaldashboard")} className="p-2 bg-[#121214] border border-[#2A2A35] rounded-lg hover:border-[#E11D48] hover:text-[#E11D48] transition-colors">
              <ArrowLeft className="w-5 h-5" />
            </button>
            <div>
              <h1 className="text-xl font-bold flex items-center gap-2">
                Emergency Dispatch
                <Activity className="w-5 h-5 text-[#E11D48]" />
              </h1>
              <p className="text-xs text-gray-400">Match & Notify Donors (30km Radius)</p>
            </div>
          </div>
        </header>

        {/* Info Strip */}
        <div className="bg-[#121214] border-b border-[#1E1E24] p-4 flex flex-wrap gap-6 shrink-0">
          <div>
            <p className="text-xs text-gray-500 uppercase tracking-widest mb-1">Patient</p>
            <p className="font-semibold flex items-center gap-1.5"><User className="w-4 h-4 text-[#E11D48]"/> {patientInfo?.name} ({patientInfo?.age}y)</p>
          </div>
          <div>
            <p className="text-xs text-gray-500 uppercase tracking-widest mb-1">Target Blood</p>
            <p className="font-semibold flex items-center gap-1.5"><Droplets className="w-4 h-4 text-[#E11D48]"/> {patientInfo?.bloodGroup}</p>
          </div>
          <div>
            <p className="text-xs text-gray-500 uppercase tracking-widest mb-1">Contact Nominee</p>
            <p className="font-semibold flex items-center gap-1.5"><Phone className="w-4 h-4 text-[#E11D48]"/> {patientInfo?.nomineeName} ({patientInfo?.contact})</p>
          </div>
        </div>

        {/* Map Area */}
        <div className="flex-1 bg-black relative">
          <MapDisplay 
            hospitalLat={hospitalInfo?.location?.lat} 
            hospitalLng={hospitalInfo?.location?.lng} 
            donors={eligibleDonors} 
            radiusLimitKM={30}
          />
          
          <div className="absolute top-4 left-4 z-[1000] bg-[#0A0A0C]/90 backdrop-blur-md rounded-xl p-3 border border-[#2A2A35]">
            <div className="flex items-center gap-2">
              <span className="flex h-3 w-3 relative">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#E11D48] opacity-75"></span>
                <span className="relative inline-flex rounded-full h-3 w-3 bg-[#E11D48]"></span>
              </span>
              <span className="font-bold text-sm tracking-wide">Radar Scanning Active</span>
            </div>
          </div>
        </div>
      </div>

      {/* Right Sidebar - Status Tracker */}
      <div className="w-full md:w-[380px] bg-[#0A0A0C] border-l border-[#1E1E24] h-screen shrink-0 flex flex-col">
        <div className="p-6 border-b border-[#1E1E24]">
           <h2 className="text-lg font-bold mb-1 flex items-center justify-between">
             Dispatch Tracker
             <span className="bg-[#E11D48]/20 text-[#E11D48] px-2 py-0.5 rounded text-xs">
               {eligibleDonors.length} Matches
             </span>
           </h2>
           <p className="text-xs text-gray-500 leading-tight">These donors match {patientInfo?.bloodGroup} and are within 30km of your facility.</p>
           
           {!requestSent ? (
              <button 
                onClick={handleSendRequests}
                disabled={eligibleDonors.length === 0}
                className="w-full mt-4 bg-[#E11D48] hover:bg-[#BE123C] text-white font-bold py-3 px-4 rounded-xl flex items-center justify-center gap-2 transition-colors shadow-lg shadow-[#E11D48]/20 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <Send className="w-5 h-5" />
                Notify All Candidates
              </button>
           ) : (
             <div className="mt-4 bg-[#121214] border border-[#2A2A35] rounded-xl p-3 flex items-center gap-3">
               <div className="w-10 h-10 rounded-full bg-green-500/20 text-green-500 flex items-center justify-center">
                 <CheckCircle2 className="w-6 h-6" />
               </div>
               <div>
                  <p className="font-bold text-sm">Requests Dispatched</p>
                  <p className="text-xs text-gray-400">Awaiting donor responses</p>
               </div>
             </div>
           )}
        </div>

        <div className="flex-1 overflow-y-auto p-4 space-y-3">
          {eligibleDonors.map((donor, idx) => (
             <div 
               key={donor.id} 
               className={`p-4 rounded-xl border transition-all duration-500 ${
                 donor.status === 'acknowledged' 
                 ? 'bg-green-500/10 border-green-500/50 shadow-[0_0_20px_rgba(34,197,94,0.1)]' 
                 : donor.status === 'pending'
                 ? 'bg-[#121214] border-[#E11D48]/30'
                 : 'bg-[#121214] border-[#1E1E24]'
               }`}
             >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <div className="bg-[#1A1A20] p-2 rounded-lg border border-[#2A2A35]">
                      <User className="w-4 h-4 text-gray-400" />
                    </div>
                    <div>
                      <p className="font-bold text-sm text-gray-200">{donor.name || 'Anonymous'}</p>
                      <p className="text-xs text-gray-500">{donor.distance.toFixed(1)} km away</p>
                    </div>
                  </div>
                  <div className="flex flex-col items-end">
                    <span className="font-bold text-[#E11D48] text-sm">{donor.bloodGroup}</span>
                  </div>
                </div>

                <div className="mt-3 flex items-center justify-between pt-3 border-t border-[#1E1E24]">
                  {donor.status === 'ready' && <span className="text-xs text-gray-500 px-2 py-1 bg-[#1E1E24] rounded-md">Not Sent</span>}
                  {donor.status === 'pending' && <span className="text-xs text-orange-400 flex items-center gap-1.5"><span className="animate-pulse w-2 h-2 rounded-full bg-orange-400"></span> Pending Response</span>}
                  {donor.status === 'acknowledged' && <span className="text-xs text-green-500 font-bold flex items-center gap-1"><CheckCircle2 className="w-3 h-3"/> I Can Help!</span>}
                  
                  {(donor.status === 'acknowledged') && (
                    <button className="text-xs bg-[#2A2A35] hover:bg-[#3f3f4e] text-white px-2 py-1 rounded transition-colors flex items-center gap-1">
                      <Phone className="w-3 h-3" /> Call {donor.phone}
                    </button>
                  )}
                </div>
             </div>
          ))}
          {eligibleDonors.length === 0 && (
            <div className="text-center p-8">
              <MapPin className="w-8 h-8 text-[#E11D48]/30 mx-auto mb-3" />
              <p className="text-sm text-gray-500">No match found within 30km radius for {patientInfo?.bloodGroup}.</p>
            </div>
          )}
        </div>
      </div>

    </div>
  );
}

export default function RequestsPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-[#050505] text-white flex items-center justify-center">Loading Dispatch Tool...</div>}>
      <RequestsContent />
    </Suspense>
  );
}
