"use client";

import { useEffect, useState, useMemo } from 'react';
import { collection, getDocs, doc, setDoc, addDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../lib/firebase';
import dynamic from 'next/dynamic';
import { Phone, AlertTriangle, MapPin, Heart, Award } from 'lucide-react';

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
  const [donationCounts, setDonationCounts] = useState({}); // {donorId: count}
  const [markingDonated, setMarkingDonated] = useState(null); // Track which donor is being marked
  const [donationNotes, setDonationNotes] = useState('');
  const [showDonationModal, setShowDonationModal] = useState(null); // donorId for modal

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

  // Fetch donation counts for each donor
  useEffect(() => {
    async function fetchDonationCounts() {
      const counts = {};
      for (const donor of donors) {
        try {
          const donationsCol = collection(db, `users/${donor.id}/donations`);
          const donationsSnap = await getDocs(donationsCol);
          counts[donor.id] = donationsSnap.size;
        } catch (e) {
          counts[donor.id] = 0;
        }
      }
      setDonationCounts(counts);
    }
    if (donors.length > 0) fetchDonationCounts();
  }, [donors]);

  const handleMarkDonated = async (donorId, bloodType) => {
    setMarkingDonated(donorId);
    try {
      const donationsCol = collection(db, `users/${donorId}/donations`);
      await addDoc(donationsCol, {
        date: Date.now(),
        bloodType: bloodType || urgentBloodType,
        hospitalLat: parseFloat(hospitalLat),
        hospitalLng: parseFloat(hospitalLng),
        notes: donationNotes || 'Blood donation completed',
      });
      // Update donation count locally
      setDonationCounts(prev => ({ ...prev, [donorId]: (prev[donorId] || 0) + 1 }));
      setShowDonationModal(null);
      setDonationNotes('');
      alert('Donation recorded successfully!');
    } catch (error) {
      console.error(error);
      alert('Failed to record donation.');
    } finally {
      setMarkingDonated(null);
    }
  };

  const handleInformDonor = async (donorId) => {
    setInforming(donorId);
    try {
      // Write the request to the donor's personal request inbox
      const reqPath = 'users/' + donorId + '/requests'; await setDoc(doc(db, reqPath, Date.now().toString()), {
        timestamp: Date.now(),
        hospitalLat: parseFloat(hospitalLat),
        hospitalLng: parseFloat(hospitalLng),
        bloodType: urgentBloodType,
        message: 'URGENT: A nearby hospital requires ' + urgentBloodType + ' blood immediately! You are close to the location. Can you help?',
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
                      <div className="donor-name">
                        {donor.name || 'Ghost Node'}
                        {donationCounts[donor.id] > 0 && (
                          <span className="donation-count-badge" title={`${donationCounts[donor.id]} past donations`}>
                            <Heart size={10} /> {donationCounts[donor.id]}
                          </span>
                        )}
                      </div>
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
                      {isUrgentMode && (
                        <button 
                          className="btn btn-donated" 
                          style={{ flex: 1, padding: '0.5rem' }} 
                          disabled={markingDonated === donor.id}
                          onClick={() => setShowDonationModal(donor.id)}
                        >
                          <Award size={14} />
                          {markingDonated === donor.id ? 'Saving...' : 'DONATED'}
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
      
      {/* Donation Modal */}
      {showDonationModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(8px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 9999 }}>
          <div className="panel" style={{ maxWidth: '420px', width: '90%' }}>
            <h3 style={{ marginBottom: '1rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <Award size={20} color="var(--accent-primary)" /> Record Donation
            </h3>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.875rem', marginBottom: '1.5rem' }}>
              Confirm that this donor has successfully donated blood.
            </p>
            <div className="form-group">
              <label>Notes (optional)</label>
              <input
                type="text"
                placeholder="e.g. Donated 1 unit at City Hospital"
                value={donationNotes}
                onChange={(e) => setDonationNotes(e.target.value)}
              />
            </div>
            <div style={{ display: 'flex', gap: '0.75rem' }}>
              <button className="btn btn-secondary" style={{ flex: 1 }} onClick={() => { setShowDonationModal(null); setDonationNotes(''); }}>Cancel</button>
              <button
                className="btn"
                style={{ flex: 1 }}
                disabled={markingDonated === showDonationModal}
                onClick={() => handleMarkDonated(showDonationModal, urgentBloodType)}
              >
                {markingDonated === showDonationModal ? 'Recording...' : 'Confirm Donation'}
              </button>
            </div>
          </div>
        </div>
      )}

      <style dangerouslySetInnerHTML={{__html: `
        @keyframes spin { 100% { transform: rotate(360deg); } }
      `}} />
    </div>
  );
}
