<template>
<div class="doctor-container">
  <div class="doctor-card">
    <div class="doctor-welcome" v-if="isLoggedIn">
      <h3>
        <i class="fas fa-user-md"></i>
        Welcome, 
        <span v-for="org in orgs" v-if="org.id==jwt.oid">
          <span v-for="user in org.users" v-if="user.uid==jwt.uid">
            Dr. {{ user.name }}
          </span>
        </span>
        <span v-if="!orgs || orgs.length === 0 || !orgs.find(org => org.id === jwt.oid)">
          Dr. {{ jwt.name || 'John Smith' }}
        </span>
        <span class="specialty-badge" v-if="jwt.specialty">{{ jwt.specialty }}</span>
      </h3>
    </div>

    <div v-if="!isLoggedIn">
      <div class="placeholder-container">
        <i class="fas fa-user-md placeholder-icon"></i>
        <h3>Doctor Portal</h3>
        <p>Please log in to access the doctor dashboard</p>
      </div>
    </div>

    <div v-if="isLoggedIn" class="doctor-dashboard">
      <div class="tabs-container">
        <tabs 
          :tabs="tabs"
          :currentTab="currentTab"
          :wrapper-class="'doctor-tabs'"
          :tab-class="'doctor-tabs__item'"
          :tab-active-class="'doctor-tabs__item_active'"
          :line-class="'doctor-tabs__active-line'"
          @onClick="tabClick" />
     
        <!-- POST DOC JSON -->
        <div class="doctor-form" v-if="currentTab=='post-doc'">
          <div class="form-header">
            <h4>Create New Medical Record</h4>
            <p>Upload a new patient medical record to the blockchain</p>
          </div>
          <div class="form-grid">
            <div class="form-group">
              <label>Document Name <span class="required">*</span></label>
              <input type="text" v-model="doctor.postdocname" class="form-control" placeholder="Enter document name">
            </div>
            <div class="form-group">
              <label>Document Data <span class="required">*</span></label>
              <textarea v-model="doctor.postdoccontent" class="form-control doc-content" placeholder="Enter medical data (e.g. JSON format)"></textarea>
            </div>
            <div class="form-actions">
              <button type="button" class="btn-upload" v-on:click="postDocJson()">
                <i class="fas fa-upload"></i> Upload Document
              </button>
            </div>
          </div>
        </div>

        <!-- GET DOC -->
        <div class="doctor-form" v-if="currentTab=='get-doc'">
          <div class="form-header">
            <h4>Access Patient Records</h4>
            <p>View medical records that patients have shared with you</p>
          </div>
          <div class="form-grid">
            <div class="form-group">
              <label>Select Patient <span class="required">*</span></label>
              <select class="form-control" v-model="doctor.getdocuser" @change="getDocListForUser">
                <option value="" selected disabled>Select Patient</option>
                <option v-for="user in availablePatients" :value="user.id" :key="user.id">
                  {{ user.name }}
                </option>
              </select>
            </div>
            <div class="form-group">
              <label>Select Document <span class="required">*</span></label>
              <select class="form-control" v-model="doctor.getdocid">
                <option value="" selected disabled>Select Document</option>
                <option v-for="doc in docListForUser" :key="doc.id">
                  {{ doc.name }}
                </option>
              </select>
            </div>
            <div class="form-actions">
              <button type="button" class="btn-download" v-on:click="getDoc()">
                <i class="fas fa-file-medical"></i> View Document
              </button>
            </div>
          </div>
        </div>
        
        <!-- VIEW PATIENTS -->
        <div class="doctor-form" v-if="currentTab=='view-patients'">
          <div class="form-header">
            <h4>My Patients</h4>
            <p>View patients that have shared medical records with you</p>
          </div>
          <div class="patients-container">
            <div class="patients-info">
              <span class="info-badge"><i class="fas fa-users"></i> {{ availablePatients.length }}</span>
              You have access to {{ availablePatients.length }} patient records
            </div>
            
            <div v-if="availablePatients.length === 0" class="empty-state">
              <i class="fas fa-user-injured empty-icon"></i>
              <p>No patients have shared records with you yet</p>
            </div>
            
            <div class="table-wrapper" v-else>
              <table class="table">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Available Documents</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="patient in availablePatients" :key="patient.id">
                    <td>
                      <span class="user-icon">
                        <i class="fas fa-user"></i>
                      </span>
                      {{ patient.name }}
                    </td>
                    <td>{{ patient.email }}</td>
                    <td>
                      <span class="doc-count">{{ patient.documents ? patient.documents.length : 0 }}</span>
                    </td>
                    <td>
                      <button class="action-btn view-btn" @click="viewPatientDocuments(patient)">
                        <i class="fas fa-eye"></i> View
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <div class="response-container" v-if="Object.keys(response).length > 0 && currentTab != 'view-patients'">
        <div class="response-header">
          <i class="fas fa-file-medical-alt"></i> 
          {{ currentTab === 'post-doc' ? 'Upload Status' : 'Medical Record Data' }}
        </div>
        <tree-view :data="response" />
      </div>
    </div>
  </div>
</div>
</template>

<script>                                                      
import Api from '@/apis/DoctorApi'
import RedisApi from '@/apis/RedisApi'
import Tabs from 'vue-tabs-with-active-line'
import { serverBus } from '@/main'

const TABS = [
  { title: 'Upload Document', value: 'post-doc'},
  { title: 'Access Patient Records', value: 'get-doc'},
  { title: 'View Patients', value: 'view-patients'},
]

export default {
  name: 'Doctor',
  props: {
  },
  components: {
    Tabs
  },
  data: () => ({
    response: {},
    orgs: [],
    tabs: TABS,
    currentTab: 'post-doc',
    doctor: {},
    availablePatients: [],
    docListForUser: [],
    userListForDoc: [],
    caller: 'user-doctor',
    isLogin: false,
    isLoggedIn: false,
    jwt: {},
    selectedPatient: null
  }),
  created() {
    // Check if already logged in via session storage
    if (sessionStorage[`${this.caller}-token`] && sessionStorage[`${this.caller}-token`] !== '') {
      this.isLoggedIn = true;
      try {
        // Try to decode existing JWT if available
        const VueJwtDecode = require('vue-jwt-decode').default;
        this.jwt = VueJwtDecode.decode(sessionStorage[`${this.caller}-token`]);
      } catch (e) {
        console.log("Could not decode existing token");
      }
    }
    
    serverBus.$on('allOrgs', (allOrgs) => {
      this.orgs = allOrgs || []
      if (this.isLoggedIn) {
        this.getAvailablePatients()
      }
    });
    
    serverBus.$on(`${this.caller}-isLogin`, (login) => {
      this.isLogin = login
    });
    
    serverBus.$on(`${this.caller}-isLoggedIn`, (login) => {
      this.isLoggedIn = login
      this.doctor = {}
      this.response = {}
      
      if (login) {
        this.currentTab = 'post-doc'
        this.getAvailablePatients()
      }
    });
    
    serverBus.$on(`${this.caller}-jwt`, (decodedJWT) => {
      this.jwt = decodedJWT || {}
      
      // If we're logged in but have no patients yet, create dummy data
      if (this.isLoggedIn && (!this.availablePatients || this.availablePatients.length === 0)) {
        this.createDummyData();
      }
    });
  },
  methods: {
    tabClick(newTab) {
      this.currentTab = newTab;
      this.response = {};
      this.doctor = {};
      
      if (newTab === 'view-patients' || newTab === 'get-doc') {
        this.getAvailablePatients();
      }
    },

    setRequestProcessing() {
      this.response = {
        status: "Request processing..."
      };
    },
    
    createDummyData() {
      // Only create dummy data if in development mode and doctor is logged in
      if (process.env.NODE_ENV !== 'production' && this.isLoggedIn) {
        // Create dummy patients with shared records
        const dummyPatients = [
          {
            id: 'user-patient-1',
            name: 'John Doe',
            email: 'john.doe@example.com',
            documents: [
              { id: 'doc-123', name: 'Blood Test Results' },
              { id: 'doc-456', name: 'Annual Physical Exam' }
            ]
          },
          {
            id: 'user-patient-2',
            name: 'Emma Wilson',
            email: 'emma.wilson@example.com',
            documents: [
              { id: 'doc-789', name: 'Cardiology Report' }
            ]
          }
        ];
        
        // Only set this data if we don't already have patient data
        if (!this.availablePatients || this.availablePatients.length === 0) {
          this.availablePatients = dummyPatients;
        }
      }
    },

    async postDocJson() {
      var docName = this.doctor.postdocname;
      var docContent = this.doctor.postdoccontent;
     
      if (!docName || !docContent) {
        this.response = {
          error: "Please provide both document name and content"
        };
        return;
      }
      
      this.setRequestProcessing();

      try {
        const apiResponse = await Api.postDocJson({
          name: docName,
          content: docContent
        });
        
        this.response = apiResponse.data;
        this.getPostDocStatus(apiResponse.data.response.correlationId, docName);
      } catch (error) {
        console.error("Error uploading document:", error);
        this.response = { 
          error: "Failed to upload document",
          details: error.message
        };
      }
    },

    async getPostDocStatus(corrId, docName) {
      if (corrId) {
        try {
          const apiResponse = await Api.getPostDocStatus({
            correlationId: corrId
          });
          
          this.response = apiResponse.data;
          
          if (apiResponse.data[corrId].transactionStatus != "initiated") {
            this.response = {
              status: "Document uploaded successfully",
              documentId: Object.keys(apiResponse.data[corrId].documentStatus)[0],
              name: docName
            };
            
            var userName = null;
            var userEmail = null;
            for (var org of this.orgs) {
              if (org.id == this.jwt.oid) {
                for (var user of org.users) {
                  if (user.uid == this.jwt.uid) {
                    userName = user.name;
                    userEmail = user.userId;
                    break;
                  }
                }
              }
            }

            // If we couldn't find user details in orgs, use JWT data
            if (!userName) {
              userName = this.jwt.name || "Doctor";
              userEmail = this.jwt.email || "doctor@hospital.com";
            }

            await RedisApi.postUserToDocMapping(this.jwt.uid, {
              id: Object.keys(apiResponse.data[corrId].documentStatus)[0],
              name: docName
            });
            
            await RedisApi.postDocToUserMapping(Object.keys(apiResponse.data[corrId].documentStatus)[0], [{
              id: this.jwt.uid,
              name: userName,
              email: userEmail
            }]);
            
            // Clear the form fields
            this.doctor.postdocname = '';
            this.doctor.postdoccontent = '';
          } else {
            setTimeout(() => this.getPostDocStatus(corrId, docName), 1000);
          }
        } catch (error) {
          console.error("Error getting document status:", error);
          this.response = { 
            error: "Failed to get document status",
            details: error.message
          };
        }
      }
    },

    async getAvailablePatients() {
      // Reset the list
      this.availablePatients = [];
      
      // Show loading state
      const loadingResponse = { status: "Loading patients..." };
      if (this.currentTab === 'view-patients') {
        this.response = loadingResponse;
      }
      
      try {
        // Get all patients that have shared documents with this doctor
        for (var org of this.orgs || []) {
          for (var user of org.users || []) {
            if (user.roles && user.roles[0] === 'PATIENT' && user.uid !== this.jwt.uid) {
              try {
                // Check if this patient has shared any documents with the doctor
                const docResponse = await RedisApi.getUserToDocMapping(user.uid);
                if (docResponse.data) {
                  const docs = JSON.parse(docResponse.data);
                  if (docs && docs.length > 0) {
                    // For each document, check if doctor has access
                    let hasAccess = false;
                    let accessibleDocs = [];
                    
                    for (let doc of docs) {
                      const accessResponse = await RedisApi.getDocToUserMapping(doc.id);
                      if (accessResponse.data) {
                        const users = JSON.parse(accessResponse.data);
                        for (let u of users) {
                          if (u.id === this.jwt.uid) {
                            hasAccess = true;
                            accessibleDocs.push(doc);
                            break;
                          }
                        }
                      }
                    }
                    
                    if (hasAccess) {
                      this.availablePatients.push({
                        id: user.uid,
                        name: user.name,
                        email: user.userId,
                        documents: accessibleDocs
                      });
                    }
                  }
                }
              } catch (error) {
                console.error("Error checking patient access:", error);
              }
            }
          }
        }
        
        // If no patients found and in development mode, use dummy data
        if (this.availablePatients.length === 0 && process.env.NODE_ENV !== 'production') {
          this.createDummyData();
        }
        
        // Clear loading state
        if (this.currentTab === 'view-patients' && this.response === loadingResponse) {
          this.response = {};
        }
      } catch (error) {
        console.error("Error loading patients:", error);
        if (this.currentTab === 'view-patients') {
          this.response = { error: "Failed to load patients" };
        }
      }
    },

    async getDocListForUser() {
      var uid = this.doctor.getdocuser;
      
      if (uid) {
        this.docListForUser = [];
        // Find the patient in our available patients list
        for (let patient of this.availablePatients) {
          if (patient.id === uid) {
            this.docListForUser = patient.documents || [];
            break;
          }
        }
      }
    },

    async getDoc() {
      var docName = this.doctor.getdocid;
      
      if (!docName) {
        this.response = { error: "Please select a document" };
        return;
      }

      var docId = null;
      for (var doc of this.docListForUser) {
        if (doc.name == docName) {
          docId = doc.id;
          break;
        }
      }

      if (docId) {
        this.setRequestProcessing();

        try {
          const apiResponse = await Api.getDoc({
            docId: docId
          });
          
          // If the response is JSON, parse it
          if (apiResponse.data && apiResponse.data.jsonContent) {
            try {
              this.response = JSON.parse(apiResponse.data.jsonContent);
            } catch (e) {
              this.response = apiResponse.data;
            }
          } else {
            this.response = apiResponse.data;
          }
        } catch (error) {
          console.error("Error fetching document:", error);
          this.response = { error: "Failed to fetch document" };
        }
      }
    },

    viewPatientDocuments(patient) {
      // Set this patient's document list
      this.docListForUser = patient.documents || [];
      this.doctor.getdocuser = patient.id;
      
      // Switch to the get-doc tab
      this.currentTab = 'get-doc';
    }
  }
}
</script>                                                                  
                                                                            
<!-- Add "scoped" attribute to limit CSS to this component only -->          
<style scoped>
.doctor-container {
  width: 100%;
  height: 100%;
  max-width: 1200px;
  margin: 0 auto;
}

.doctor-card {
  background-color: #1e1e2e;
  border-radius: 12px;
  overflow: hidden;
  height: 100%;
  box-shadow: 0 4px 12px rgba(0,0,0,0.3);
  display: flex;
  flex-direction: column;
}

.doctor-welcome {
  padding: 24px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  background-color: #2a2a3c;
}

.doctor-welcome h3 {
  margin: 0;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
}

.doctor-welcome i {
  font-size: 1.5rem;
  color: #3498db;
}

.specialty-badge {
  background-color: rgba(52, 152, 219, 0.2);
  color: #3498db;
  padding: 6px 12px;
  border-radius: 20px;
  font-size: 0.8rem;
  font-weight: 600;
  margin-left: auto;
}

.placeholder-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 350px;
  color: #aaa;
  padding: 24px;
}

.placeholder-container p {
  margin-top: 15px;
  color: #888;
  font-size: 1.1rem;
}

.placeholder-container h3 {
  font-size: 1.8rem;
  margin-top: 16px;
}

.placeholder-icon {
  font-size: 3rem;
  color: #3498db;
  opacity: 0.5;
}

.doctor-dashboard {
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
}

.tabs-container {
  padding: 24px;
  flex: 0 0 auto;
}

.doctor-tabs {
  display: flex;
  margin-bottom: 24px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  overflow-x: auto;
}

.doctor-tabs__item {
  padding: 12px 18px;
  margin-right: 12px;
  color: #aaa;
  cursor: pointer;
  border: none;
  background: none;
  font-size: 0.95rem;
  transition: all 0.2s ease;
  white-space: nowrap;
  font-weight: 500;
}

.doctor-tabs__item_active {
  color: #3498db;
}

.doctor-tabs__active-line {
  background-color: #3498db;
  height: 3px;
}

.doctor-form {
  padding: 16px 0;
}

.form-header {
  margin-bottom: 24px;
  text-align: left;
}

.form-header h4 {
  color: #3498db;
  font-size: 1.25rem;
  margin: 0 0 8px 0;
}

.form-header p {
  color: #aaa;
  margin: 0;
  font-size: 0.95rem;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 20px;
}

.form-group {
  text-align: left;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  font-size: 0.9rem;
  color: #ccc;
  font-weight: 500;
}

.required {
  color: #e74c3c;
  margin-left: 4px;
}

.form-control {
  width: 100%;
  padding: 12px 16px;
  border-radius: 8px;
  border: 1px solid rgba(255,255,255,0.15);
  background-color: rgba(73,73,73,0.5) !important;
  color: white;
  font-size: 1rem;
  transition: all 0.2s ease;
}

.doc-content {
  min-height: 150px;
  resize: vertical;
  font-family: monospace;
}

.form-control:focus {
  outline: none;
  border-color: rgba(52, 152, 219, 0.5);
  box-shadow: 0 0 0 3px rgba(52, 152, 219, 0.2);
}

.form-control::placeholder {
  color: rgba(255,255,255,0.4);
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  margin-top: 16px;
}

.btn-upload, .btn-download {
  padding: 12px 20px;
  border-radius: 8px;
  border: none;
  color: white;
  cursor: pointer;
  font-size: 0.95rem;
  transition: all 0.2s ease;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 8px;
}

.btn-upload {
  background-color: #3498db;
}

.btn-download {
  background-color: #2ecc71;
}

.btn-upload:hover, .btn-download:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0,0,0,0.2);
}

.btn-upload:active, .btn-download:active {
  transform: translateY(0);
}

.response-container {
  margin: 0 24px 24px;
  background-color: rgba(73,73,73,0.7);
  border-radius: 8px;
  padding: 20px;
  overflow: auto;
  flex: 1;
  text-align: left;
}

.response-header {
  font-size: 1rem;
  color: #3498db;
  margin-bottom: 16px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  padding-bottom: 12px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 8px;
}

.patients-container {
  padding: 16px 0;
}

.patients-info {
  font-size: 1rem;
  color: #ccc;
  margin-bottom: 20px;
  text-align: left;
  display: flex;
  align-items: center;
  gap: 12px;
}

.info-badge {
  background-color: rgba(52, 152, 219, 0.15);
  color: #3498db;
  padding: 8px 12px;
  border-radius: 8px;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-weight: 600;
}

.table-wrapper {
  border-radius: 8px;
  overflow: hidden;
  background-color: rgba(73,73,73,0.7);
  max-height: 450px;
  overflow-y: auto;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
}

.table {
  width: 100%;
  border-collapse: collapse;
  color: #fff;
}

.table th, .table td {
  padding: 14px;
  text-align: left;
  border-bottom: 1px solid rgba(255,255,255,0.05);
}

.table th {
  background-color: rgba(0,0,0,0.2);
  font-weight: 600;
  color: #3498db;
  font-size: 0.95rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.table tr:hover {
  background-color: rgba(255,255,255,0.05);
}

.table td {
  vertical-align: middle;
}

.user-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  background-color: rgba(46, 204, 113, 0.15);
  color: #2ecc71;
  border-radius: 50%;
  margin-right: 10px;
}

.doc-count {
  background-color: rgba(52, 152, 219, 0.15);
  color: #3498db;
  font-weight: 600;
  padding: 4px 10px;
  border-radius: 16px;
}

.action-btn {
  padding: 6px 12px;
  border-radius: 6px;
  border: none;
  font-size: 0.85rem;
  transition: all 0.2s ease;
  cursor: pointer;
  color: white;
  display: inline-flex;
  align-items: center;
  gap: 5px;
}

.view-btn {
  background-color: #3498db;
}

.view-btn:hover {
  background-color: #2980b9;
  transform: translateY(-1px);
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 0;
  color: #888;
}

.empty-icon {
  font-size: 4rem;
  color: #3498db;
  opacity: 0.4;
  margin-bottom: 24px;
}

@media (min-width: 768px) {
  .form-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .form-grid .form-group:nth-child(2) {
    grid-column: span 2;
  }
}

@media (max-width: 768px) {
  .doctor-tabs {
    flex-wrap: nowrap;
    overflow-x: auto;
    padding-bottom: 5px;
  }
  
  .doctor-tabs__item {
    padding: 10px 12px;
    font-size: 0.9rem;
  }
  
  .patients-info {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }
  
  .table th, .table td {
    padding: 10px 8px;
    font-size: 0.9rem;
  }
  
  .action-btn {
    padding: 4px 8px;
    font-size: 0.8rem;
  }
}
</style>
