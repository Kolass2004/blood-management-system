"use client";

import { useEffect, useState, useMemo } from 'react';
import { collection, getDocs, doc, setDoc } from 'firebase/firestore';
import { db } from '../lib/firebase';
import dynamic from 'next/dynamic';
import { Phone, AlertTriangle, MapPin } from 'lucide-react';

// Dynamically import MapPicker so Leaflet doesn't crash on server side
const MapPicker = dynamic(() => import('../components/MapPicker'), {
  ssr: false,
  loading: () => <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-secondary)' }}>Loading Map System...</div>
});

// Helper function to calculate distance in km using Haversine formula
function calculateDistance(lat1, lon1, lat2, lon2) {
  if (!lat1 || !lon1 || !lat2 || !lon2) return Infinity;
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

export default function Dashboard() {
  const [donors, setDonors] = useState([]);
  const [loading, setLoading] = useState(true);

  // Filters
  const [filterBlood, setFilterBlood] = useState('All');
  
  // Map and Request State
  const [hospitalLat, setHospitalLat] = useState('13.0827'); 
  const [hospitalLng, setHospitalLng] = useState('80.2707');
  const [urgentBloodType, setUrgentBloodType] = useState('');
  const [isUrgentMode, setIsUrgentMode] = useState(false);
  const [informing, setInforming] = useState(null); // Track which user is being informed

  useEffect(() => {
    async function fetchDonors() {
      try {
        const usersCol = collection(db, 'users');
        const userSnapshot = await getDocs(usersCol);
        const usersList = userSnapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        }));
        
        setDonors(usersList);
      } catch (error) {
        console.error("Error fetching donors:", error);
      } finally {
        setLoading(false);
      }
    }
    fetchDonors();
  }, []);

  const handleInformDonor = async (donorId) => {
    setInforming(donorId);
    try {
      // Write the request to the donor's personal request inbox
      await setDoc(doc(db, `users/\${donorId}/requests`, Date.now().toString()), {
        timestamp: Date.now(),
        hospitalLat: parseFloat(hospitalLat),
        hospitalLng: parseFloat(hospitalLng),
        bloodType: urgentBloodType,
        message: `URGENT: A nearby hospital requires \${urgentBloodType} blood immediately! You are close to the location. Can you help?`,
        status: "pending"
      });
      alert('Alert pushed safely to donor!');
    } catch (error) {
      console.error(error);
      alert('Failed to inform donor.');
    } finally {
      setInforming(null);
    }
  };

  const mapDonors = useMemo(() => {
    // Inject distances for map sorting
    return donors.map(d => {
      let dist = Infinity;
      if (d.location && d.location.lat && d.location.lng) {
        dist = calculateDistance(
          parseFloat(hospitalLat), 
          parseFloat(hospitalLng), 
          d.location.lat, 
          d.location.lng
        );
      }
      return { ...d, distance: dist };
    });
  }, [donors, hospitalLat, hospitalLng]);

  const processedDonors = useMemo(() => {
    let result = [...mapDonors];

    if (isUrgentMode && urgentBloodType) {
      result = result.filter(d => d.bloodGroup === urgentBloodType);
      result.sort((a, b) => a.distance - b.distance);
    } else {
      if (filterBlood !== 'All') {
        result = result.filter(d => d.bloodGroup === filterBlood);
      }
    }
    return result;
  }, [mapDonors, filterBlood, isUrgentMode, urgentBloodType]);

  return (
    <div className="container">
      <h1 className="title">Blood Management Portal</h1>
      
      <div className="dashboard-grid">
        {/* Sidebar Controls */}
        <div className="panel" style={{ position: 'sticky', top: '2rem' }}>
          <h2>Parameters</h2>
          <div style={{ marginTop: '1.5rem' }}>
            <div className="form-group">
              <label>Standard Filter</label>
              <select 
                value={filterBlood} 
                onChange={(e) => {
                  setFilterBlood(e.target.value);
                  setIsUrgentMode(false);
                }}
              >
                <option value="All">All Blood Types</option>
                <option value="A+">A+</option>
                <option value="A-">A-</option>
                <option value="B+">B+</option>
                <option value="B-">B-</option>
                <option value="O+">O+</option>
                <option value="O-">O-</option>
                <option value="AB+">AB+</option>
                <option value="AB-">AB-</option>
              </select>
            </div>

            <hr style={{ borderColor: 'var(--border-color)', margin: '2rem 0' }} />

            <h3 style={{ color: 'var(--accent-primary)', marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <span style={{ width: '8px', height: '8px', background: 'var(--accent-primary)', borderRadius: '50%', boxShadow: '0 0 10px var(--accent-glow)' }}></span>
              Emergency Mode
            </h3>
            
            <div className="form-group">
              <label>Required Blood Type</label>
              <select 
                value={urgentBloodType} 
                onChange={(e) => setUrgentBloodType(e.target.value)}
              >
                <option value="">Select Type...</option>
                <option value="A+">A+</option>
                <option value="A-">A-</option>
                <option value="B+">B+</option>
                <option value="B-">B-</option>
                <option value="O+">O+</option>
                <option value="O-">O-</option>
                <option value="AB+">AB+</option>
                <option value="AB-">AB-</option>
              </select>
            </div>
            
            <p style={{ fontSize: '0.875rem', color: 'var(--text-secondary)', marginBottom: '1rem' }}>
              Click your location on the map to set the hospital coordinates dynamically.
            </p>
            
            <button 
              className="btn" 
              onClick={() => {
                if (urgentBloodType) {
                  setIsUrgentMode(true);
                  setFilterBlood('All'); // Reset standard filter
                } else {
                  alert("Please select a blood type for the urgent request.");
                }
              }}
            >
              Scan Deep Network
            </button>
            {isUrgentMode && (
              <button 
                className="btn btn-secondary" 
                style={{ marginTop: '1rem' }}
                onClick={() => setIsUrgentMode(false)}
              >
                Disengage Protocol
              </button>
            )}
          </div>
        </div>

        {/* Content Area */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
          
          <div className="panel map-container" style={{ padding: 0 }}>
            <MapPicker 
              donors={mapDonors}
              defaultLat={hospitalLat} 
              defaultLng={hospitalLng} 
              onLocationSelect={(lat, lng) => {
                setHospitalLat(lat.toString());
                setHospitalLng(lng.toString());
              }} 
            />
          </div>

          <div className="panel" style={{ background: 'transparent', border: 'none', boxShadow: 'none', padding: '0' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
              <h2>Active Nodes {isUrgentMode && <span className="urgent-badge">LIVE SCAN</span>}</h2>
              <span style={{ color: 'var(--accent-primary)', fontWeight: '600' }}>{processedDonors.length} found</span>
            </div>

            <div className="donors-list">
              {loading ? (
                <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
                  <div style={{ width: '2rem', height: '2rem', border: '3px solid var(--border-color)', borderTopColor: 'var(--accent-primary)', borderRadius: '50%', animation: 'spin 1s linear infinite' }} />
                  <p>Establishing link...</p>
                </div>
              ) : processedDonors.length > 0 ? (
                processedDonors.map(donor => (
                  <div key={donor.id} className="donor-card" style={{ borderColor: isUrgentMode ? 'rgba(239, 68, 68, 0.4)' : '' }}>
                    <div className="donor-header">
                      <div className="donor-name">{donor.name || 'Ghost Node'}</div>
                      <div className="blood-badge">{donor.bloodGroup || 'N/A'}</div>
                    </div>
                    
                    <div className="donor-details">
                      <div className="detail-row">
                        <Phone size={16} className="detail-icon" /> {donor.phone || 'Classified'}
                      </div>
                      {donor.allergies && (
                        <div className="detail-row">
                          <AlertTriangle size={16} className="detail-icon" /> {donor.allergies}
                        </div>
                      )}
                      
                      {isUrgentMode && (
                        <div className="detail-row" style={{ color: 'var(--text-primary)', fontWeight: '600', marginTop: '0.5rem' }}>
                          <MapPin size={16} className="detail-icon" style={{ color: 'var(--accent-primary)' }} />
                          {donor.distance === Infinity 
                            ? 'Location Shielded' 
                            : `\${donor.distance.toFixed(1)} km out`}
                        </div>
                      )}
                    </div>
                    
                    <div className="card-actions">
                      <a href={`tel:\${donor.phone}`} className="btn btn-secondary" style={{ flex: 1 }}>
                        Call
                      </a>
                      {isUrgentMode && (
                        <button 
                          className="btn" 
                          style={{ flex: 1, padding: '0.5rem' }} 
                          disabled={informing === donor.id || donor.distance === Infinity}
                          onClick={() => handleInformDonor(donor.id)}
                        >
                          {informing === donor.id ? 'Pinging...' : 'INFORM'}
                        </button>
                      )}
                    </div>
                  </div>
                ))
              ) : (
                <div className="panel" style={{ gridColumn: '1 / -1', textAlign: 'center', padding: '3rem' }}>
                  <p style={{ color: 'var(--text-secondary)' }}>No active nodes detected mapping to criteria.</p>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
      
      <style dangerouslySetInnerHTML={{__html: `
        @keyframes spin { 100% { transform: rotate(360deg); } }
      `}} />
    </div>
  );
}
