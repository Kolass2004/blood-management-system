import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyDWRtBEbxJG4XRL-qZA82GSXc3v6atRBD0",
  authDomain: "blood-management-75f1a.firebaseapp.com",
  projectId: "blood-management-75f1a",
  storageBucket: "blood-management-75f1a.firebasestorage.app",
  messagingSenderId: "586594687915",
  appId: "1:586594687915:web:282203c7a74402f8e050ee"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
