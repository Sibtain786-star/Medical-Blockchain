<template>
  <div class="admin-container">
    <div class="admin-card">
      <div class="admin-welcome" v-if="isLoggedIn">
        <h3>Solution Administrator Dashboard</h3>
      </div>

      <div v-if="!isLoggedIn">
        <div class="placeholder-container">
          <h3>System Admin Portal</h3>
          <p>Please log in to access administrative functions</p>
        </div>
      </div>
      
      <div v-if="isLoggedIn" class="admin-dashboard">
        <div class="tabs-container">
          <tabs
            :tabs="tabs"
            :currentTab="currentTab"
            :wrapper-class="'admin-tabs'"
            :tab-class="'admin-tabs__item'"
            :tab-active-class="'admin-tabs__item_active'"
            :line-class="'admin-tabs__active-line'"
            @onClick="tabClick" />
        
          <!-- VIEW SOLUTION -->
          <div class="admin-form" v-if="currentTab=='get-solution'">
            <div class="form-grid">
              <div class="form-group">
                <label>Solution ID: {{ solutionId }}</label>
              </div>
              <div class="form-actions">
                <button type="button" class="btn-view" v-on:click="getSolutionById()">View Solution Details</button>
              </div>
            </div>
          </div>

          <!-- PUT ORG -->
          <div class="admin-form" v-if="currentTab=='put-org'">
            <div class="form-grid">
              <div class="form-group">
                <label>Hospital Name</label>
                <input type="text" v-model="admin.putorgorgname" class="form-control" placeholder="Enter hospital name">
              </div>
              <div class="form-actions">
                <button type="button" class="btn-add" v-on:click="putOrgs()">Add Hospital</button>
              </div>
            </div>
          </div>

          <!-- POST ORG ADMIN -->
          <div class="admin-form" v-if="currentTab=='post-org-admin'">
            <div class="form-grid">
              <div class="form-group">
                <label>Select Hospital</label>
                <select class="form-control" v-model="admin.postorgadminorgid">
                  <option value="" selected disabled>Select Hospital</option>
                  <option v-for="org in orgs" :value="org.name">
                    {{ org.name }}
                  </option>
                </select>
              </div>
              <div class="form-group">
                <label>Admin Email</label>
                <input type="text" v-model="admin.postorgadminadmin" class="form-control" placeholder="Enter admin email address">
              </div>
              <div class="form-actions">
                <button type="button" class="btn-add" v-on:click="postOrgAdmin()">Add Admin</button>
              </div>
            </div>
          </div>
          
          <!-- DELETE ORG ADMIN -->
          <div class="admin-form" v-if="currentTab=='delete-org-admin'">
            <div class="form-grid">
              <div class="form-group">
                <label>Select Hospital</label>
                <select class="form-control" v-model="admin.delorgadminorgid">
                  <option value="" selected disabled>Select Hospital</option>
                  <option v-for="org in orgs" :value="org.name">
                    {{ org.name }}
                  </option>
                </select>
              </div>
              <div class="form-group">
                <label>Admin Email</label>
                <input type="text" v-model="admin.delorgadminadmin" class="form-control" placeholder="Enter admin email address">
              </div>
              <div class="form-actions">
                <button type="button" class="btn-delete" v-on:click="deleteOrgAdmin()">Remove Admin</button>
              </div>
            </div>
          </div>
          
          <!-- VIEW ORGANIZATIONS -->
          <div class="admin-form" v-if="currentTab=='view-orgs'">
            <div class="orgs-container">
              <div class="orgs-info">There are {{ orgs ? orgs.length : 0 }} hospitals in the system.</div>
              <div class="table-wrapper">
                <table class="table">
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Organization ID</th>
                      <th>Users</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="org in orgs">
                      <td>{{ org.name }}</td>
                      <td>{{ org.id }}</td>
                      <td>{{ org.users ? org.users.length : 0 }}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        <div class="response-container" v-if="Object.keys(response).length > 0 && currentTab != 'view-orgs'">
          <div class="response-header">Response Data</div>
          <tree-view :data="response" />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Api from '@/apis/AdminApi'
import Tabs from 'vue-tabs-with-active-line'
import { serverBus } from '@/main'

const TABS = [
  { title: 'Solution Details', value: 'get-solution'},
  { title: 'Add Hospital', value: 'put-org'},
  { title: 'Add Hospital Admin', value: 'post-org-admin'},
  { title: 'Remove Hospital Admin', value: 'delete-org-admin'},
  { title: 'View Hospitals', value: 'view-orgs'},
]

export default {
  name: 'Admin',
  components: {
    Tabs
  },
  data: () => ({
    response: {},
    orgs: [],
    docs: [],
    tabs: TABS,
    currentTab: 'get-solution',
    admin: {},
    isLoggedIn: false,
    solutionId: '',
    jwt: {},
    caller: 'admin'
  }),
  created () {
    serverBus.$on('allOrgs', (allOrgs) => {
      this.orgs = allOrgs
    }),
    serverBus.$on('triggerGetOrgs', (orgId) => {
      this.searchAllUsersForOrgId(orgId)
    }),
    serverBus.$on(`${this.caller}-isLoggedIn`, (login) => {
      this.isLoggedIn = login
      this.admin = {}
      this.response = {}
      
      if (login) {
        this.currentTab = 'get-solution'
        this.getSolutionById()
      }
    }),
    serverBus.$on(`${this.caller}-jwt`, (decodedJWT) => {
      this.jwt = decodedJWT
      this.solutionId = this.jwt.sid || 'medrec_demo'
    })
  },
  methods: {
    tabClick (newTab) {
      this.currentTab = newTab
      this.response = {}
      this.admin = {}

      if (this.currentTab == 'get-solution')
        this.getSolutionById()
    },

    setRequestProcessing () {
      this.response = {
        status: "Request processing..."
      }
    },

    async getSolutionById () {
      var solId = this.solutionId
      
      if (solId) {
        this.setRequestProcessing()

        const apiResponse = await Api.getSolutionById(solId)
        this.response = apiResponse.data
      }
    },

    async putOrgs () {
      var orgName = this.admin.putorgorgname
      var solId = this.solutionId
      if (orgName && solId) {
        this.setRequestProcessing()
        
        const apiResponse = await Api.putOrgs({
          name: orgName,
          solutionId: solId
        })
        this.response = apiResponse.data
        this.searchAllOrgs()
      }
    },

    async searchAllOrgs () {
      var solId = this.solutionId
      if (solId) {
        const apiResponse = await Api.searchAllOrgs({
          solutionId: solId
        })
        this.orgs = apiResponse.data.response
        serverBus.$emit('allOrgs', this.orgs)
        this.searchAllUsers()
      }
    },

    searchAllUsers () {
      for (var org of this.orgs) {
        this.searchAllUsersForOrgId(org.id)
      }
      serverBus.$emit('allOrgs', this.orgs)
    },

    async searchAllUsersForOrgId (orgId) {
      var solId = this.solutionId
      if (solId) {
        const apiResponse = await Api.searchAllUsersForOrgId({
          solutionId: solId,
          organizationId: orgId,
          count: false
        })

        var orgIndex = null
        for (var index in this.orgs) {
          if (this.orgs[index].id == orgId) {
            orgIndex = index
            break
          }
        }

        if (apiResponse.data.response) {
          this.$set(this.orgs[orgIndex], 'users', apiResponse.data.response)
        } else {
          this.$set(this.orgs[orgIndex], 'users', [])
        }
      }
    },

    async postOrgAdmin () {
      var solId = this.solutionId
      var admin = this.admin.postorgadminadmin
      var orgName = this.admin.postorgadminorgid
      
      var orgId = false
      // Get orgId from orgName
      for (var org of this.orgs) {
        if (org.name == orgName) {
          orgId = org.id
          break
        }
      }

      if (solId && admin && orgId) {
        this.setRequestProcessing()
        
        const apiResponse = await Api.postOrgAdmin({
          solutionId: solId,
          organizationId: orgId,
          adminEmailId: admin
        })
        this.response = apiResponse.data
        this.searchAllUsersForOrgId(orgId)
      }
    },
    
    async deleteOrgAdmin () {
      var solId = this.solutionId
      var admin = this.admin.delorgadminadmin
      var orgName = this.admin.delorgadminorgid
      
      var orgId = false
      // Get orgId from orgName
      for (var org of this.orgs) {
        if (org.name == orgName) {
          orgId = org.id
          break
        }
      }

      var adminId = false
      for (var org of this.orgs) {
        if (org.name == orgName) {
          for (var user of org.users) {
            if (user.userId == admin) {
              adminId = user.uid
              break
            }
          }
        }
      }

      if (solId && adminId && orgId) {
        this.setRequestProcessing()
        
        const apiResponse = await Api.deleteOrgAdmin({
          solutionId: solId,
          organizationId: orgId,
          adminId: adminId
        })
        this.response = apiResponse.data
        this.searchAllUsersForOrgId(orgId)
      } else {
        this.response = {
          "status": "Provided admin doesn't exist in Hospital"
        }
      }
    },

    async getAllRoles () {
      var solId = this.solutionId
      
      if (solId) {
        const apiResponse = await Api.getSolutionRoles({
          solutionId: solId
        })
        serverBus.$emit('allRoles', apiResponse.data.response)
      }
    }
  }
}
</script>                                                                  
                                                                            
<!-- Add "scoped" attribute to limit CSS to this component only -->          
<style scoped>
.admin-container {
  width: 100%;
  height: 100%;
  max-width: 1200px;
  margin: 0 auto;
}

.admin-card {
  background-color: #1e1e2e;
  border-radius: 10px;
  overflow: hidden;
  height: 100%;
  box-shadow: 0 4px 8px rgba(0,0,0,0.2);
  display: flex;
  flex-direction: column;
}

.admin-welcome {
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

.admin-dashboard {
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
}

.tabs-container {
  padding: 20px;
  flex: 0 0 auto;
}

.admin-tabs {
  display: flex;
  margin-bottom: 20px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  overflow-x: auto;
}

.admin-tabs__item {
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

.admin-tabs__item_active {
  color: #74e0df;
}

.admin-tabs__active-line {
  background-color: #74e0df;
  height: 2px;
}

.admin-form {
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

.btn-view, .btn-add, .btn-delete {
  padding: 8px 15px;
  border-radius: 5px;
  border: none;
  color: white;
  cursor: pointer;
  font-size: 0.9rem;
  transition: all 0.2s ease;
}

.btn-view {
  background-color: #3498db;
}

.btn-add {
  background-color: #2ecc71;
}

.btn-delete {
  background-color: #e74c3c;
}

.btn-view:hover, .btn-add:hover, .btn-delete:hover {
  transform: translateY(-2px);
  box-shadow: 0 2px 5px rgba(0,0,0,0.2);
}

.btn-view:active, .btn-add:active, .btn-delete:active {
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

.orgs-container {
  padding: 10px 0;
}

.orgs-info {
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

@media (min-width: 768px) {
  .form-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
