"use client";

import { useEffect, useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMapEvents, Circle } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';

// Fix Leaflet's default icon path issues in modern frameworks
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

// A custom pulsing icon for the hospital location
const hospitalIcon = new L.DivIcon({
  className: 'hospital-marker',
  html: `<div style="background-color: #ef4444; width: 20px; height: 20px; border-radius: 50%; border: 3px solid white; box-shadow: 0 0 15px rgba(239, 68, 68, 0.8);"></div>`,
  iconSize: [20, 20],
  iconAnchor: [10, 10], 
});

function LocationMarker({ position, setPosition, donors }) {
  useMapEvents({
    click(e) {
      setPosition(e.latlng);
    },
  });

  return position === null ? null : (
    <>
      <Marker position={position} icon={hospitalIcon}>
        <Popup>Hospital / Urgent Location</Popup>
      </Marker>
      <Circle center={position} radius={10000} pathOptions={{ color: '#ef4444', fillColor: '#ef4444', fillOpacity: 0.1 }} />
    </>
  );
}

export default function MapPicker({ onLocationSelect, defaultLat = 13.0827, defaultLng = 80.2707, donors = [] }) {
  const [position, setPosition] = useState({ lat: parseFloat(defaultLat), lng: parseFloat(defaultLng) });

  useEffect(() => {
    onLocationSelect(position.lat, position.lng);
  }, [position, onLocationSelect]);

  return (
    <div style={{ height: '100%', width: '100%', borderRadius: '16px', overflow: 'hidden' }}>
      <MapContainer 
        center={[position.lat, position.lng]} 
        zoom={12} 
        style={{ height: '100%', width: '100%' }}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
        />
        <LocationMarker position={position} setPosition={setPosition} donors={donors} />
        
        {/* Render Donor Markers */}
        {donors.map(donor => {
          if (!donor.location || typeof donor.location.lat !== 'number' || typeof donor.location.lng !== 'number') return null;
          return (
            <Marker 
              key={donor.id} 
              position={[donor.location.lat, donor.location.lng]}
            >
              <Popup>
                <div style={{ color: '#000', padding: '5px' }}>
                  <strong>{donor.name || 'Anonymous User'}</strong><br/>
                  Blood Group: {donor.bloodGroup}<br/>
                  Phone: {donor.phone}
                </div>
              </Popup>
            </Marker>
          );
        })}
      </MapContainer>
    </div>
  );
}
