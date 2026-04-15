"use client";

import { MapContainer, TileLayer, Marker, Popup, Circle } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';

// Fix Leaflet's default icon path issues
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const hospitalIcon = new L.DivIcon({
  className: 'hospital-marker',
  html: `<div style="background-color: #ef4444; width: 20px; height: 20px; border-radius: 50%; border: 3px solid white; box-shadow: 0 0 15px rgba(239, 68, 68, 0.8);"></div>`,
  iconSize: [20, 20],
  iconAnchor: [10, 10], 
});

export default function MapDisplay({ hospitalLat, hospitalLng, donors = [], radiusLimitKM = 30 }) {
  if (!hospitalLat || !hospitalLng) return null;

  return (
    <div style={{ height: '100%', width: '100%', borderRadius: '16px', overflow: 'hidden' }}>
      <MapContainer 
        center={[hospitalLat, hospitalLng]} 
        zoom={11} 
        style={{ height: '100%', width: '100%' }}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
        />
        
        {/* Hospital Marker */}
        <Marker position={[hospitalLat, hospitalLng]} icon={hospitalIcon}>
          <Popup>Hospital Location</Popup>
        </Marker>
        
        {/* 30km Radius Circle */}
        <Circle 
           center={[hospitalLat, hospitalLng]} 
           radius={radiusLimitKM * 1000} 
           pathOptions={{ color: '#ef4444', fillColor: '#ef4444', fillOpacity: 0.05, weight: 1, dashArray: '5, 5' }} 
        />
        
        {/* Donor Markers */}
        {donors.map(donor => {
          if (!donor.location || typeof donor.location.lat !== 'number' || typeof donor.location.lng !== 'number') return null;
          
          return (
            <Marker 
              key={donor.id} 
              position={[donor.location.lat, donor.location.lng]}
            >
              <Popup>
                <div style={{ color: '#000', padding: '5px' }}>
                  <strong>{donor.name || 'Donor'}</strong><br/>
                  Blood Group: {donor.bloodGroup}<br/>
                  Distance: {donor.distance.toFixed(1)} km<br/>
                  Status: <span style={{color: donor.status === 'acknowledged' ? 'green' : 'orange'}}>{donor.status?.toUpperCase() || 'IDLE'}</span>
                </div>
              </Popup>
            </Marker>
          );
        })}
      </MapContainer>
    </div>
  );
}
