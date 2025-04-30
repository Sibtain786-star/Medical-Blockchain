<template>
<div class="patient-container">
  <div class="patient-card">
    <div class="patient-welcome" v-if="isLoggedIn">
      <h3>
        Welcome, 
        <span v-for="org in orgs" v-if="org.id==jwt.oid">
          <span v-for="user in org.users" v-if="user.uid==jwt.uid">
            {{ user.name }}
          </span>
        </span>
      </h3>
    </div>

    <div v-if="!isLoggedIn">
      <div class="placeholder-container">
        <h3>Patient Portal</h3>
        <p>Please log in to access your medical records</p>
      </div>
    </div>

    <div v-if="isLoggedIn" class="patient-dashboard">
      <div class="tabs-container">
        <tabs 
          :tabs="tabs"
          :currentTab="currentTab"
          :wrapper-class="'patient-tabs'"
          :tab-class="'patient-tabs__item'"
          :tab-active-class="'patient-tabs__item_active'"
          :line-class="'patient-tabs__active-line'"
          @onClick="tabClick" />
     
        <!-- LIST DOCS -->
        <div class="patient-form" v-if="currentTab=='list-docs'">
          <div class="docs-container">
            <div class="docs-info">You have {{ docs ? docs.length : 0 }} medical records in the system.</div>
            <div class="table-wrapper">
              <table class="table">
                <thead>
                  <tr>
                    <th>Document Name</th>
                    <th>Document ID</th>
                    <th>Shared With</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="doc in docs">
                    <td>{{ doc.name }}</td>
                    <td class="doc-id">{{ doc.id }}</td>
                    <td>{{ doc.sharedWith ? doc.sharedWith.length : 0 }} providers</td>
                    <td>
                      <button class="btn-view" @click="viewDoc(doc.id)">View</button>
                      <button class="btn-access" @click="viewAccessLog(doc.id)">Access Log</button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- GIVE ACCESS -->
        <div class="patient-form" v-if="currentTab=='give-access'">
          <div class="form-grid">
            <div class="form-group">
              <label>Select Document</label>
              <select class="form-control" v-model="patient.docId">
                <option value="" selected disabled>Select Document</option>
                <option v-for="doc in docs" :value="doc.id">
                  {{ doc.name }}
                </option>
              </select>
            </div>
            <div class="form-group">
              <label>Select Provider</label>
              <select class="form-control" v-model="patient.providerId">
                <option value="" selected disabled>Select Provider</option>
                <option v-for="provider in availableProviders" :value="provider.uid">
                  Dr. {{ provider.name }}
                </option>
              </select>
            </div>
            <div class="form-actions">
              <button type="button" class="btn-share" v-on:click="shareDocument()">Share Document</button>
            </div>
          </div>
        </div>

        <!-- REVOKE ACCESS -->
        <div class="patient-form" v-if="currentTab=='revoke-access'">
          <div class="form-grid">
            <div class="form-group">
              <label>Select Document</label>
              <select class="form-control" v-model="patient.revokeDocId" @change="loadDocShares">
                <option value="" selected disabled>Select Document</option>
                <option v-for="doc in docs" :value="doc.id">
                  {{ doc.name }}
                </option>
              </select>
            </div>
            <div class="form-group">
              <label>Select Provider</label>
              <select class="form-control" v-model="patient.revokeProviderId">
                <option value="" selected disabled>Select Provider</option>
                <option v-for="provider in sharedProviders" :value="provider.id">
                  Dr. {{ provider.name }}
                </option>
              </select>
            </div>
            <div class="form-actions">
              <button type="button" class="btn-revoke" v-on:click="revokeAccess()">Revoke Access</button>
            </div>
          </div>
        </div>
      </div>

      <div class="response-container" v-if="Object.keys(response).length > 0 && currentTab != 'list-docs'">
        <div class="response-header">
          {{ currentTab === 'give-access' || currentTab === 'revoke-access' ? 'Response Data' : 'Document Data' }}
        </div>
        <tree-view :data="response" />
      </div>
    </div>
  </div>
</div>
</template>

<script>
import Api from '@/apis/PatientApi'
import RedisApi from '@/apis/RedisApi'
import Tabs from 'vue-tabs-with-active-line'
import { serverBus } from '@/main'

const TABS = [
  { title: 'My Medical Records', value: 'list-docs'},
  { title: 'Share With Provider', value: 'give-access'},
  { title: 'Manage Access', value: 'revoke-access'},
]

export default {
  name: 'Patient',
  props: {
  },
  components: {
    Tabs
  },
  data: () => ({
    response: {},
    orgs: [],
    docs: [],
    availableProviders: [],
    sharedProviders: [],
    tabs: TABS,
    currentTab: 'list-docs',
    patient: {},
    caller: 'user-patient',
    isLogin: false,
    isLoggedIn: false,
    jwt: {}
  }),
  created() {
    serverBus.$on('allOrgs', (allOrgs) => {
      this.orgs = allOrgs
      if (this.isLoggedIn) {
        this.findAvailableProviders()
        this.getAllDocs()
      }
    }),
    serverBus.$on(`${this.caller}-isLogin`, (login) => {
      this.isLogin = login
    }),
    serverBus.$on(`${this.caller}-isLoggedIn`, (login) => {
      this.isLoggedIn = login
      this.patient = {}
      this.response = {}
      
      if (login) {
        this.currentTab = 'list-docs'
        this.findAvailableProviders()
        this.getAllDocs()
      }
    }),
    serverBus.$on(`${this.caller}-jwt`, (decodedJWT) => {
      this.jwt = decodedJWT
    })
  },
  methods: {
    tabClick(newTab) {
      this.currentTab = newTab
      this.response = {}
      this.patient = {}
      
      if (newTab === 'list-docs') {
        this.getAllDocs()
      } else if (newTab === 'give-access') {
        this.findAvailableProviders()
      }
    },

    setRequestProcessing() {
      this.response = {
        status: "Request processing..."
      }
    },

    async getAllDocs() {
      this.docs = []
      
      try {
        const apiResponse = await RedisApi.getUserToDocMapping(this.jwt.uid)
        if (apiResponse.data) {
          this.docs = JSON.parse(apiResponse.data) || []
          
          // Get shared providers for each document
          for (let i = 0; i < this.docs.length; i++) {
            const doc = this.docs[i]
            const accessResponse = await RedisApi.getDocToUserMapping(doc.id)
            if (accessResponse.data) {
              // Filter out the patient (self) from the users list
              const users = JSON.parse(accessResponse.data) || []
              const sharedUsers = users.filter(user => user.id !== this.jwt.uid)
              this.$set(this.docs[i], 'sharedWith', sharedUsers)
            } else {
              this.$set(this.docs[i], 'sharedWith', [])
            }
          }
        }
      } catch (error) {
        console.error("Error getting documents:", error)
      }
    },

    async viewDoc(docId) {
      if (docId) {
        this.setRequestProcessing()

        try {
          const apiResponse = await Api.getDoc({
            docId: docId
          })
          this.response = JSON.parse(apiResponse.data.jsonContent)
        } catch (error) {
          this.response = { error: "Failed to fetch document" }
        }
      }
    },

    async viewAccessLog(docId) {
      if (docId) {
        this.setRequestProcessing()
        
        try {
          const apiResponse = await Api.getAccessLog({
            docId: docId
          })
          this.response = apiResponse.data
        } catch (error) {
          this.response = { error: "Failed to fetch access log" }
        }
      }
    },

    async findAvailableProviders() {
      this.availableProviders = []
      
      // Find all doctors in the system
      for (var org of this.orgs) {
        for (var user of org.users || []) {
          if (user.roles && user.roles[0] === 'DOCTOR') {
            this.availableProviders.push(user)
          }
        }
      }
    },

    async loadDocShares() {
      const docId = this.patient.revokeDocId
      this.sharedProviders = []
      
      if (docId) {
        try {
          const accessResponse = await RedisApi.getDocToUserMapping(docId)
          if (accessResponse.data) {
            // Filter out the patient (self) from the users list
            const users = JSON.parse(accessResponse.data) || []
            this.sharedProviders = users.filter(user => user.id !== this.jwt.uid)
          }
        } catch (error) {
          console.error("Error loading document shares:", error)
        }
      }
    },

    async shareDocument() {
      const docId = this.patient.docId
      const providerId = this.patient.providerId
      
      if (docId && providerId) {
        this.setRequestProcessing()
        
        try {
          // Get provider details
          let providerName = '', providerEmail = ''
          for (const org of this.orgs) {
            for (const user of org.users || []) {
              if (user.uid === providerId) {
                providerName = user.name
                providerEmail = user.userId
                break
              }
            }
          }
          
          // Add to Redis mapping
          await RedisApi.patchDocToUserMapping(docId, providerId)
          
          // Update the docToUser mapping with complete provider info
          const accessResponse = await RedisApi.getDocToUserMapping(docId)
          if (accessResponse.data) {
            const users = JSON.parse(accessResponse.data) || []
            // Check if provider already exists in the list
            const providerExists = users.some(u => u.id === providerId)
            
            if (!providerExists) {
              users.push({
                id: providerId,
                name: providerName,
                email: providerEmail
              })
              
              await RedisApi.postDocToUserMapping(docId, users)
            }
          }
          
          this.response = { status: "Access granted successfully" }
          
          // Refresh the docs list
          this.getAllDocs()
        } catch (error) {
          this.response = { error: "Failed to share document" }
        }
      }
    },

    async revokeAccess() {
      const docId = this.patient.revokeDocId
      const providerId = this.patient.revokeProviderId
      
      if (docId && providerId) {
        this.setRequestProcessing()
        
        try {
          // Get current shares
          const accessResponse = await RedisApi.getDocToUserMapping(docId)
          if (accessResponse.data) {
            const users = JSON.parse(accessResponse.data) || []
            // Filter out the provider we're revoking
            const updatedUsers = users.filter(user => user.id !== providerId)
            
            // Update Redis with new list
            await RedisApi.postDocToUserMapping(docId, updatedUsers)
            
            this.response = { status: "Access revoked successfully" }
            
            // Refresh the docs and shares lists
            this.getAllDocs()
            this.loadDocShares()
          }
        } catch (error) {
          this.response = { error: "Failed to revoke access" }
        }
      }
    }
  }
}
</script>                                                                  
                                                                            
<!-- Add "scoped" attribute to limit CSS to this component only -->          
<style scoped>
.patient-container {
  width: 100%;
  height: 100%;
  max-width: 1200px;
  margin: 0 auto;
}

.patient-card {
  background-color: #1e1e2e;
  border-radius: 10px;
  overflow: hidden;
  height: 100%;
  box-shadow: 0 4px 8px rgba(0,0,0,0.2);
  display: flex;
  flex-direction: column;
}

.patient-welcome {
  padding: 20px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  background-color: #2a2a3c;
}

.placeholder-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 300px;
  color: #aaa;
}

.placeholder-container p {
  margin-top: 10px;
  color: #888;
}

.patient-dashboard {
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
}

.tabs-container {
  padding: 20px;
  flex: 0 0 auto;
}

.patient-tabs {
  display: flex;
  margin-bottom: 20px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  overflow-x: auto;
}

.patient-tabs__item {
  padding: 10px 15px;
  margin-right: 10px;
  color: #aaa;
  cursor: pointer;
  border: none;
  background: none;
  font-size: 0.9rem;
  transition: all 0.2s ease;
  white-space: nowrap;
}

.patient-tabs__item_active {
  color: #74e0df;
}

.patient-tabs__active-line {
  background-color: #74e0df;
  height: 2px;
}

.patient-form {
  padding: 10px 0;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 15px;
}

.form-group {
  text-align: left;
}

.form-group label {
  display: block;
  margin-bottom: 5px;
  font-size: 0.85rem;
  color: #ccc;
}

.form-control {
  width: 100%;
  padding: 8px 12px;
  border-radius: 5px;
  border: 1px solid rgba(255,255,255,0.1);
  background-color: rgba(73,73,73,0.5) !important;
  color: white;
  font-size: 0.9rem;
}

.form-control:focus {
  outline: none;
  border-color: rgba(116,224,223,0.5);
  box-shadow: 0 0 0 2px rgba(116,224,223,0.2);
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  margin-top: 10px;
}

.btn-view, .btn-access, .btn-share, .btn-revoke {
  padding: 6px 12px;
  border-radius: 5px;
  border: none;
  color: white;
  cursor: pointer;
  font-size: 0.8rem;
  transition: all 0.2s ease;
  margin-left: 5px;
}

.btn-view {
  background-color: #3498db;
}

.btn-access {
  background-color: #9b59b6;
}

.btn-share {
  background-color: #2ecc71;
}

.btn-revoke {
  background-color: #e74c3c;
}

.btn-view:hover, .btn-access:hover, .btn-share:hover, .btn-revoke:hover {
  transform: translateY(-2px);
  box-shadow: 0 2px 5px rgba(0,0,0,0.2);
}

.btn-view:active, .btn-access:active, .btn-share:active, .btn-revoke:active {
  transform: translateY(0);
}

.response-container {
  margin: 0 20px 20px;
  background-color: rgba(73,73,73,0.7);
  border-radius: 5px;
  padding: 15px;
  overflow: auto;
  flex: 1;
  text-align: left;
}

.response-header {
  font-size: 0.9rem;
  color: #74e0df;
  margin-bottom: 10px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  padding-bottom: 5px;
}

.docs-container {
  padding: 10px 0;
}

.docs-info {
  font-size: 0.9rem;
  color: #ccc;
  margin-bottom: 15px;
  text-align: left;
}

.table-wrapper {
  border-radius: 5px;
  overflow: hidden;
  background-color: rgba(73,73,73,0.7);
  max-height: 380px;
  overflow-y: auto;
}

.table {
  width: 100%;
  border-collapse: collapse;
  color: #fff;
}

.table th, .table td {
  padding: 10px;
  text-align: left;
  border-bottom: 1px solid rgba(255,255,255,0.05);
}

.table th {
  background-color: rgba(0,0,0,0.2);
  font-weight: 500;
  color: #74e0df;
}

.table tr:hover {
  background-color: rgba(255,255,255,0.05);
}

.doc-id {
  font-size: 0.8rem;
  color: #aaa;
}

@media (min-width: 768px) {
  .form-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
