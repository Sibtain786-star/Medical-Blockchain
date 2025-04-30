<template>
  <div id="app">
    <header class="app-header">
      <h1 class="app-title">Medical Blockchain</h1>
      <nav class="app-nav">
        <div 
          v-for="panel in panels" 
          :key="panel.id"
          :class="['nav-item', activePanel === panel.id ? 'active' : '']"
          @click.prevent="setActivePanel(panel.id)">
          {{ panel.name }}
        </div>
      </nav>
      <div class="user-info">
        <span v-if="isUserLoggedIn" class="user-name">{{ currentUser }}</span>
        <button class="btn-logout" v-if="isUserLoggedIn" @click="logout">Logout</button>
        <button class="btn-login" v-else @click="showLoginModal = true">Login</button>
      </div>
    </header>

    <main class="app-main">
      <Admin v-if="activePanel === 'admin'" class="panel-component"></Admin>
      <Organization v-if="activePanel === 'organization'" class="panel-component"></Organization>
      <Doctor v-if="activePanel === 'doctor'" class="panel-component"></Doctor>
      <Patient v-if="activePanel === 'patient'" class="panel-component"></Patient>
    </main>

    <!-- Login Modal -->
    <div class="modal-overlay" v-if="showLoginModal" @click.self="showLoginModal = false">
      <div class="login-modal">
        <div class="modal-header">
          <h3>Login to {{ panelName }}</h3>
          <button class="modal-close" @click="showLoginModal = false">&times;</button>
        </div>
        <div class="modal-body">
          <div class="login-intro">
            <p>Please select a user to log in as or enter a JWT token.</p>
          </div>
          <div class="dummy-logins">
            <h4>Quick Login Options</h4>
            <div class="login-options">
              <button class="dummy-login" v-for="user in filteredDummyUsers" :key="user.id" @click="dummyLogin(user)">
                <div class="user-icon"><i :class="user.icon"></i></div>
                <div class="user-info-container">
                  <div class="user-title">{{ user.name }}</div>
                  <div class="user-subtitle">{{ user.role }}</div>
                </div>
              </button>
            </div>
          </div>
          <div class="jwt-login">
            <h4>Login with JWT Token</h4>
            <textarea 
              class="form-control" 
              v-model="token" 
              placeholder="Paste token here..."></textarea>
            <button class="btn-submit" @click="verifyLogin">Login with Token</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Admin from '@/components/Admin'
import Organization from '@/components/Organization'
import Doctor from '@/components/Doctor'
import Patient from '@/components/Patient'
import VueJwtDecode from 'vue-jwt-decode'
import { serverBus } from '@/main'

export default {
  name: 'app',
  components: {
    Admin,
    Organization,
    Doctor,
    Patient
  },
  data() {
    return {
      activePanel: 'admin',
      showLoginModal: false,
      isUserLoggedIn: false,
      currentUser: '',
      token: '',
      panels: [
        { id: 'admin', name: 'Admin Dashboard', caller: 'admin' },
        { id: 'organization', name: 'Hospital Admin', caller: 'org' },
        { id: 'doctor', name: 'Doctor Portal', caller: 'user-doctor' },
        { id: 'patient', name: 'Patient Portal', caller: 'user-patient' }
      ],
      dummyUsers: [
        { 
          id: 1, 
          name: 'System Admin', 
          role: 'System Administrator',
          type: 'admin', 
          caller: 'admin',
          detailedName: 'Medical System Administrator',
          icon: 'fas fa-user-shield'
        },
        { 
          id: 2, 
          name: 'Dr. Hospital Admin', 
          role: 'Hospital Administrator',
          type: 'organization', 
          caller: 'org',
          detailedName: 'Central Hospital Administrator',
          icon: 'fas fa-hospital-user'
        },
        { 
          id: 3, 
          name: 'Dr. John Smith', 
          role: 'Cardiology',
          type: 'doctor', 
          caller: 'user-doctor',
          detailedName: 'Dr. John Smith',
          icon: 'fas fa-user-md'
        },
        { 
          id: 4, 
          name: 'Dr. Sarah Johnson', 
          role: 'Neurology',
          type: 'doctor', 
          caller: 'user-doctor',
          detailedName: 'Dr. Sarah Johnson',
          icon: 'fas fa-user-md'
        },
        { 
          id: 5, 
          name: 'Patient John Doe', 
          role: 'Patient',
          type: 'patient', 
          caller: 'user-patient',
          detailedName: 'John Doe',
          icon: 'fas fa-user'
        },
        { 
          id: 6, 
          name: 'Patient Emma Wilson', 
          role: 'Patient',
          type: 'patient', 
          caller: 'user-patient',
          detailedName: 'Emma Wilson',
          icon: 'fas fa-user'
        }
      ]
    }
  },
  computed: {
    panelName() {
      const panel = this.panels.find(p => p.id === this.activePanel);
      return panel ? panel.name : 'Dashboard';
    },
    currentCaller() {
      const panel = this.panels.find(p => p.id === this.activePanel);
      return panel ? panel.caller : 'admin';
    },
    filteredDummyUsers() {
      // Show all users if we're on admin, otherwise filter to show only relevant users
      if (this.activePanel === 'admin') {
        return this.dummyUsers.filter(user => user.type === 'admin');
      } else if (this.activePanel === 'organization') {
        return this.dummyUsers.filter(user => user.type === 'organization');
      } else if (this.activePanel === 'doctor') {
        return this.dummyUsers.filter(user => user.type === 'doctor');
      } else if (this.activePanel === 'patient') {
        return this.dummyUsers.filter(user => user.type === 'patient');
      }
      return this.dummyUsers;
    }
  },
  created() {
    sessionStorage['admin-token'] = ""
    sessionStorage['org-token'] = ""
    sessionStorage['user-doctor-token'] = ""
    sessionStorage['user-patient-token'] = ""
    
    // Load Font Awesome for icons
    if (!document.getElementById('fontawesome-css')) {
      const link = document.createElement('link');
      link.id = 'fontawesome-css';
      link.rel = 'stylesheet';
      link.href = 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css';
      document.head.appendChild(link);
    }
  },
  methods: {
    setActivePanel(panelId) {
      if (this.activePanel === panelId) return;
      
      // Check if user is logged in for the current role
      if (sessionStorage[`${this.currentCaller}-token`] === "") {
        this.logout();
      }
      
      this.activePanel = panelId;
      
      // Check if user is already logged in for the new role
      if (sessionStorage[`${this.currentCaller}-token`] !== "") {
        this.isUserLoggedIn = true;
        // Get user name from stored data
        const user = this.dummyUsers.find(u => u.type === this.activePanel);
        this.currentUser = user ? user.detailedName || user.name : 'User';
      } else {
        this.isUserLoggedIn = false;
        this.currentUser = '';
        // Show login modal automatically when switching to a panel without login
        this.showLoginModal = true;
      }
    },
    
    logout() {
      sessionStorage[`${this.currentCaller}-token`] = "";
      this.isUserLoggedIn = false;
      this.currentUser = '';
      serverBus.$emit(`${this.currentCaller}-isLoggedIn`, false);
      serverBus.$emit(`${this.currentCaller}-jwt`, {});
    },
    
    dummyLogin(user) {
      // Create mock JWT token structure with more realistic data
      const mockToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkR1bW15IFVzZXIiLCJpYXQiOjE1MTYyMzkwMjIsInVpZCI6InVzZXItMTIzIiwib2lkIjoib3JnLTEyMyIsInNpZCI6Im1lZHJlY19kZW1vIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c";
      
      // Store token in session storage
      sessionStorage[`${user.caller}-token`] = mockToken;
      
      // Update login state
      this.isUserLoggedIn = true;
      this.currentUser = user.detailedName || user.name;
      
      // Emit events
      serverBus.$emit(`${user.caller}-isLogin`, false);
      serverBus.$emit(`${user.caller}-isLoggedIn`, true);
      
      // Create mock JWT decode result based on role with more specific data
      const jwt = {
        uid: `user-${user.id}`,
        oid: `org-${user.id}`,
        sid: 'medrec_demo',
        name: user.detailedName || user.name
      };
      
      // Add extra role-specific data to the JWT
      if (user.type === 'doctor') {
        jwt.specialty = user.role;
        jwt.licenseNumber = `MD-${10000 + user.id}`;
      } else if (user.type === 'patient') {
        jwt.patientId = `P-${100000 + user.id}`;
      } else if (user.type === 'organization') {
        jwt.hospitalName = 'Central Hospital';
        jwt.department = 'Administration';
      } else if (user.type === 'admin') {
        jwt.accessLevel = 'Global';
        jwt.permissions = ['all'];
      }
      
      serverBus.$emit(`${user.caller}-jwt`, jwt);
      
      // Close modal
      this.showLoginModal = false;
      
      // If in development, log the successful login
      if (process.env.NODE_ENV !== 'production') {
        console.log(`Logged in as ${user.name} with role ${user.type}`);
        console.log('JWT payload:', jwt);
      }
    },
    
    verifyLogin() {
      if (!this.token) return;
      
      try {
        // Try to decode the token
        const jwt = VueJwtDecode.decode(this.token);
        
        // Store token in session storage
        sessionStorage[`${this.currentCaller}-token`] = this.token;
        
        // Update login state
        this.isUserLoggedIn = true;
        this.currentUser = jwt.name || 'User';
        
        // Emit events
        serverBus.$emit(`${this.currentCaller}-isLogin`, false);
        serverBus.$emit(`${this.currentCaller}-isLoggedIn`, true);
        serverBus.$emit(`${this.currentCaller}-jwt`, jwt);
        
        // Reset token and close modal
        this.token = '';
        this.showLoginModal = false;
      } catch (error) {
        console.error('Invalid token:', error);
      }
    }
  }
}
</script>

<style>
body {
  margin: 0;
  padding: 0;
  height: 100vh;
  width: 100vw;
  overflow: hidden;
  background-color: #121212;
  color: #e0e0e0;
  font-family: 'Avenir', Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#app {
  height: 100vh;
  width: 100vw;
  display: flex;
  flex-direction: column;
}

.app-header {
  background-color: #1e1e2e;
  padding: 1rem 2rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
  z-index: 100;
}

.app-title {
  color: #74e0df;
  font-size: 1.5rem;
  font-weight: 500;
  margin: 0;
}

.app-nav {
  display: flex;
  gap: 1.25rem;
  align-items: center;
  justify-content: center;
  padding: 0 1rem;
}

.nav-item {
  padding: 0.75rem 1.25rem;
  cursor: pointer;
  border-radius: 5px;
  transition: all 0.2s ease;
  color: #aaa;
  font-weight: 500;
  text-align: center;
}

.nav-item:hover {
  background-color: rgba(255,255,255,0.1);
  color: #fff;
}

.nav-item.active {
  color: #74e0df;
  background-color: rgba(116,224,223,0.1);
}

.user-info {
  display: flex;
  align-items: center;
  gap: 1rem;
  color: #fff;
}

.user-name {
  background-color: rgba(116,224,223,0.1);
  padding: 0.5rem 1rem;
  border-radius: 5px;
  color: #74e0df;
  font-weight: 500;
}

.btn-login, .btn-logout, .btn-submit {
  padding: 0.5rem 1rem;
  border-radius: 5px;
  border: none;
  cursor: pointer;
  transition: all 0.2s ease;
  font-weight: 500;
  min-width: 90px;
  text-align: center;
}

.btn-login {
  background-color: #3498db;
  color: white;
}

.btn-logout {
  background-color: #e74c3c;
  color: white;
}

.btn-submit {
  background-color: #74e0df;
  color: #1e1e2e;
  display: block;
  margin: 0 auto;
  min-width: 120px;
  padding: 0.75rem 1.5rem;
  font-size: 1rem;
}

.btn-login:hover, .btn-logout:hover, .btn-submit:hover {
  transform: translateY(-2px);
  box-shadow: 0 2px 5px rgba(0,0,0,0.2);
}

.app-main {
  flex: 1;
  padding: 1.5rem;
  overflow: auto;
  background-color: #121212;
}

.panel-component {
  height: 100%;
  width: 100%;
  position: static !important;
  padding: 1.5rem;
}

.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0,0,0,0.8);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
  backdrop-filter: blur(5px);
}

.login-modal {
  background-color: #1e1e2e;
  border-radius: 12px;
  width: 90%;
  max-width: 550px;
  max-height: 85vh;
  overflow: hidden;
  box-shadow: 0 8px 30px rgba(0,0,0,0.5);
}

.modal-header {
  padding: 1.25rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  background-color: #2a2a3c;
  border-bottom: 1px solid rgba(255,255,255,0.1);
}

.modal-header h3 {
  margin: 0;
  color: #74e0df;
  font-size: 1.3rem;
  font-weight: 500;
}

.modal-close {
  background: transparent;
  border: none;
  color: #aaa;
  font-size: 1.5rem;
  cursor: pointer;
  padding: 0;
}

.modal-close:hover {
  color: #fff;
}

.modal-body {
  padding: 1.5rem;
  overflow-y: auto;
}

.login-intro {
  text-align: center;
  margin-bottom: 1.5rem;
  color: #aaa;
}

.dummy-logins, .jwt-login {
  margin-bottom: 2rem;
  background-color: rgba(42, 42, 60, 0.5);
  padding: 1.5rem;
  border-radius: 10px;
}

.dummy-logins h4, .jwt-login h4 {
  color: #74e0df;
  margin-top: 0;
  font-size: 1.1rem;
  margin-bottom: 1.25rem;
  text-align: center;
  font-weight: 500;
}

.login-options {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 1rem;
}

.dummy-login {
  padding: 1rem;
  border: none;
  border-radius: 8px;
  background-color: rgba(73,73,73,0.7);
  color: white;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  gap: 1rem;
  text-align: left;
}

.dummy-login:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 10px rgba(0,0,0,0.3);
  background-color: rgba(116,224,223,0.15);
}

.user-icon {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background-color: rgba(116,224,223,0.15);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.25rem;
  color: #74e0df;
}

.user-info-container {
  display: flex;
  flex-direction: column;
}

.user-title {
  font-weight: 500;
  font-size: 0.95rem;
}

.user-subtitle {
  color: #aaa;
  font-size: 0.8rem;
  margin-top: 2px;
}

textarea.form-control {
  width: 100%;
  min-height: 120px;
  background-color: rgba(73,73,73,0.7);
  color: white;
  border: 1px solid rgba(255,255,255,0.15);
  border-radius: 8px;
  padding: 1rem;
  margin-bottom: 1.5rem;
  font-family: monospace;
  resize: vertical;
  font-size: 0.9rem;
}

textarea.form-control:focus {
  outline: none;
  border-color: rgba(116,224,223,0.5);
  box-shadow: 0 0 0 2px rgba(116,224,223,0.2);
}

input, select {
  background-color: rgba(73,73,73,0.7) !important;
  color: white !important;
  border: 1px solid rgba(255,255,255,0.15) !important;
  padding: 0.75rem 1rem !important;
  border-radius: 8px !important;
  font-size: 0.95rem !important;
}

input:focus, select:focus {
  outline: none !important;
  border-color: rgba(116,224,223,0.5) !important;
  box-shadow: 0 0 0 2px rgba(116,224,223,0.2) !important;
}

::placeholder {
  color: #888 !important;
  opacity: 0.7 !important;
}

/* Tree view styling */
.tree-view-item-key {
  color: #74e0df !important;
}

.tree-view-item {
  color: #ffffff !important;
}

h3 {
  padding-top: 7px;
  color: rgb(116, 224, 223) !important;
}

/* Additional responsive styles */
@media (max-width: 768px) {
  .app-header {
    flex-direction: column;
    padding: 1rem;
  }
  
  .app-nav {
    width: 100%;
    overflow-x: auto;
    padding: 0.75rem 0;
    gap: 0.5rem;
    justify-content: flex-start;
  }
  
  .nav-item {
    padding: 0.5rem 0.75rem;
    font-size: 0.9rem;
    white-space: nowrap;
  }
  
  .user-info {
    width: 100%;
    justify-content: flex-end;
    padding-top: 0.75rem;
  }
  
  .login-options {
    grid-template-columns: 1fr;
  }
}
</style>
