<template>
<div class="org-container">
  <div class="org-card">
    <div class="org-welcome" v-if="isLoggedIn">
      <h3>
        <i class="fas fa-hospital"></i>
        <span v-for="org in orgs" v-if="org.id==jwt.oid">
          {{ org.name || 'Central Hospital' }}
        </span>
        <span v-if="!orgs || orgs.length === 0">Central Hospital Admin Portal</span>
      </h3>
    </div>

    <div v-if="!isLoggedIn">
      <div class="placeholder-container">
        <h3>Hospital Admin Portal</h3>
        <p>Please log in to access the hospital administration dashboard</p>
      </div>
    </div>

    <div v-if="isLoggedIn" class="org-dashboard">
      <div class="tabs-container">
        <tabs 
          :tabs="tabs"
          :currentTab="currentTab"
          :wrapper-class="'org-tabs'"
          :tab-class="'org-tabs__item'"
          :tab-active-class="'org-tabs__item_active'"
          :line-class="'org-tabs__active-line'"
          @onClick="tabClick" />
     
        <!-- PUT ORG USER -->
        <div class="org-form" v-if="currentTab=='put-org-user'">
          <div class="form-grid">
            <div class="form-group">
              <label>User Name</label>
              <input type="text" v-model="admin.putorgusername" class="form-control" placeholder="Enter user name">
            </div>
            <div class="form-group">
              <label>User Email</label>
              <input type="text" v-model="admin.putorguseremail" class="form-control" placeholder="Enter user email">
            </div>
            <div class="form-group">
              <label>User Role</label>
              <select class="form-control" v-model="admin.putorguserrole">
                <option value="" selected disabled>Select Role</option>
                <option v-for="role in roles" :key="role.id">
                  {{ role.name }}
                </option>
              </select>
            </div>
            <div class="form-actions">
              <button type="button" class="btn-add" v-on:click="putOrgUser()">Add User</button>
            </div>
          </div>
        </div>

        <!-- DELETE ORG USER -->
        <div class="org-form" v-if="currentTab=='del-org-user'">
          <div class="form-grid">
            <div class="form-group" v-for="org in orgs" v-if="org.id==jwt.oid">
              <label>Select User</label>
              <select class="form-control" v-model="admin.delorgusername">
                <option value="" selected disabled>Select User</option>
                <option v-for="user in org.users" v-if="user.uid!=jwt.uid" :key="user.uid">
                  {{ user.name }}
                </option>
              </select>
            </div>
            <div class="form-actions">
              <button type="button" class="btn-delete" v-on:click="delOrgUser()">Delete User</button>
            </div>
          </div>
        </div>
        
        <!-- VIEW USERS -->
        <div class="org-form" v-if="currentTab=='view-users'">
          <div class="users-container" v-for="org in orgs" v-if="org.id==jwt.oid">
            <div class="users-info">
              <span class="info-badge"><i class="fas fa-users"></i> {{ org.users ? org.users.length : 0 }}</span>
              There are {{ org.users ? org.users.length : 0 }} users in this hospital.
            </div>
            <div class="table-wrapper">
              <table class="table">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Role</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="user in org.users" :key="user.uid">
                    <td>
                      <span class="user-icon">
                        <i :class="user.roles && user.roles[0] === 'DOCTOR' ? 'fas fa-user-md' : 'fas fa-user'"></i>
                      </span>
                      {{ user.name }}
                    </td>
                    <td>{{ user.userId }}</td>
                    <td>
                      <span class="role-badge" :class="{'role-doctor': user.roles && user.roles[0] === 'DOCTOR', 'role-patient': user.roles && user.roles[0] === 'PATIENT'}">
                        <span v-for="role in roles" v-if="role.id==user.roles[0]" :key="role.id">
                          {{ role.name }}
                        </span>
                        <span v-if="!user.roles || user.roles.length === 0">Unknown</span>
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
          <div class="users-container" v-if="!orgs || orgs.length === 0 || !orgs.find(org => org.id === jwt.oid)">
            <div class="empty-state">
              <i class="fas fa-hospital-user empty-icon"></i>
              <p>Hospital information is being loaded or not available.</p>
            </div>
          </div>
        </div>
      </div>

      <div class="response-container" v-if="Object.keys(response).length > 0 && currentTab != 'view-users'">
        <div class="response-header">Response Data</div>
        <tree-view :data="response" />
      </div>
    </div>
  </div>
</div>
</template>

<script>                                                      
import Api from '@/apis/OrganizationApi'
import Tabs from 'vue-tabs-with-active-line'
import { serverBus } from '@/main'

const TABS = [
  { title: 'Add User', value: 'put-org-user'},
  { title: 'Delete User', value: 'del-org-user'},
  { title: 'View Users', value: 'view-users'},
]

export default {
  name: 'Organization',
  components: {
    Tabs
  },
  data: () => ({
    response: {},
    orgs: [],
    roles: [],
    tabs: TABS,
    currentTab: 'put-org-user',
    admin: {},
    orgclick: {},
    caller: 'org',
    isLogin: false,
    isLoggedIn: false,
    jwt: {},
    solutionId: '',
    loadingUsers: false
  }),
  created() {
    // Check if already logged in via session storage
    if (sessionStorage[`${this.caller}-token`] && sessionStorage[`${this.caller}-token`] !== '') {
      this.isLoggedIn = true;
      try {
        // Try to decode existing JWT if available
        const VueJwtDecode = require('vue-jwt-decode').default;
        this.jwt = VueJwtDecode.decode(sessionStorage[`${this.caller}-token`]);
        this.solutionId = this.jwt.sid || 'medrec_demo';
      } catch (e) {
        console.log("Could not decode existing token");
      }
    }
    
    serverBus.$on('allOrgs', (allOrgs) => {
      this.orgs = allOrgs || [];
    }),
    serverBus.$on('allRoles', (allRoles) => {
      this.roles = allRoles || [];
    }),
    serverBus.$on(`${this.caller}-isLogin`, (login) => {
      this.isLogin = login;
    }),
    serverBus.$on(`${this.caller}-isLoggedIn`, (login) => {
      this.isLoggedIn = login;
      this.admin = {};
      this.response = {};
      
      if (login) {
        this.currentTab = 'put-org-user';
      }
    }),
    serverBus.$on(`${this.caller}-jwt`, (decodedJWT) => {
      this.jwt = decodedJWT || {};
      this.solutionId = this.jwt.sid || 'medrec_demo';
      
      // If we just logged in, create some dummy data for hospital admin
      if (!this.orgs || this.orgs.length === 0) {
        // Create dummy organizations and roles if needed for development
        this.createDummyData();
      }
    });
  },
  methods: {
    tabClick(newTab) {
      this.currentTab = newTab;
      this.response = {};
      this.admin = {};
    },

    setRequestProcessing() {
      this.response = {
        status: "Request processing..."
      };
    },

    createDummyData() {
      // Only create dummy data if in development mode
      if (process.env.NODE_ENV !== 'production') {
        const dummyOrg = {
          name: 'Central Hospital',
          id: this.jwt.oid || 'org-123',
          users: [
            {
              name: 'Dr. Hospital Admin',
              userId: 'admin@hospital.com',
              uid: this.jwt.uid || 'user-123',
              roles: ['ADMIN']
            },
            {
              name: 'Dr. John Smith',
              userId: 'john.smith@hospital.com',
              uid: 'user-456',
              roles: ['DOCTOR']
            },
            {
              name: 'Patient John Doe',
              userId: 'john.doe@example.com',
              uid: 'user-789',
              roles: ['PATIENT']
            }
          ]
        };
        
        const dummyRoles = [
          { id: 'ADMIN', name: 'Administrator' },
          { id: 'DOCTOR', name: 'Doctor' },
          { id: 'PATIENT', name: 'Patient' }
        ];
        
        this.orgs = [dummyOrg];
        this.roles = dummyRoles;
      }
    },

    async putOrgUser() {
      var solId = this.solutionId;
      var userName = this.admin.putorgusername;
      var userEmail = this.admin.putorguseremail;
      var roleName = this.admin.putorguserrole;
      
      var orgId = this.jwt.oid;

      var roleId = null;
      // Get roleId from roleName
      for (var role of this.roles) {
        if (role.name == roleName) {
          roleId = role.id;
          break;
        }
      }
      
      if (orgId && solId && userName && userEmail && roleId) {
        this.setRequestProcessing();

        try {
          const apiResponse = await Api.putOrgUser({
            orgId: orgId,
            solutionId: solId,
            name: userName,
            userId: userEmail,
            roleId: roleId
          });
          
          this.response = apiResponse.data;
          serverBus.$emit('triggerGetOrgs', orgId);
          
          // Add user to local data if in development mode
          if (process.env.NODE_ENV !== 'production') {
            for (let org of this.orgs) {
              if (org.id === orgId) {
                const newUser = {
                  name: userName,
                  userId: userEmail,
                  uid: `user-${Date.now()}`, // Generate a unique ID
                  roles: [roleId]
                };
                
                if (!org.users) org.users = [];
                org.users.push(newUser);
                break;
              }
            }
          }
        } catch (error) {
          console.error("Error adding user:", error);
          this.response = { error: "Failed to add user" };
        }
      }
    },

    async delOrgUser() {
      var solId = this.solutionId;
      var userName = this.admin.delorgusername;
      
      var orgId = this.jwt.oid;

      var userDocId = null;
      // Get userDocId from userName
      for (var org of this.orgs) {
        if (org.id == orgId) {
          for (var user of org.users || []) {
            if (user.name == userName) {
              userDocId = user.uid;
              break;
            }
          }
        }
      }

      if (orgId && solId && userDocId) {
        this.setRequestProcessing();

        try {
          const apiResponse = await Api.delOrgUser({
            orgId: orgId,
            solutionId: solId,
            userDocId: userDocId,
          });
          
          this.response = apiResponse.data;
          serverBus.$emit('triggerGetOrgs', orgId);
          
          // Remove user from local data if in development mode
          if (process.env.NODE_ENV !== 'production') {
            for (let org of this.orgs) {
              if (org.id === orgId && org.users) {
                org.users = org.users.filter(u => u.uid !== userDocId);
                break;
              }
            }
          }
        } catch (error) {
          console.error("Error deleting user:", error);
          this.response = { error: "Failed to delete user" };
        }
      }
    },
  }
}
</script>                                                                  
                                                                            
<!-- Add "scoped" attribute to limit CSS to this component only -->          
<style scoped>
.org-container {
  width: 100%;
  height: 100%;
  max-width: 1200px;
  margin: 0 auto;
}

.org-card {
  background-color: #1e1e2e;
  border-radius: 10px;
  overflow: hidden;
  height: 100%;
  box-shadow: 0 4px 8px rgba(0,0,0,0.2);
  display: flex;
  flex-direction: column;
}

.org-welcome {
  padding: 24px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  background-color: #2a2a3c;
}

.org-welcome h3 {
  margin: 0;
  display: flex;
  align-items: center;
  gap: 12px;
}

.org-welcome i {
  font-size: 1.5rem;
  color: #74e0df;
}

.placeholder-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 350px;
  color: #aaa;
}

.placeholder-container p {
  margin-top: 15px;
  color: #888;
  font-size: 1.1rem;
}

.placeholder-container h3 {
  font-size: 1.8rem;
}

.org-dashboard {
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
}

.tabs-container {
  padding: 24px;
  flex: 0 0 auto;
}

.org-tabs {
  display: flex;
  margin-bottom: 24px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  overflow-x: auto;
}

.org-tabs__item {
  padding: 12px 18px;
  margin-right: 12px;
  color: #aaa;
  cursor: pointer;
  border: none;
  background: none;
  font-size: 0.95rem;
  transition: all 0.2s ease;
  white-space: nowrap;
}

.org-tabs__item_active {
  color: #74e0df;
}

.org-tabs__active-line {
  background-color: #74e0df;
  height: 3px;
}

.org-form {
  padding: 16px 0;
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

.form-control:focus {
  outline: none;
  border-color: rgba(116,224,223,0.5);
  box-shadow: 0 0 0 3px rgba(116,224,223,0.2);
}

.form-control::placeholder {
  color: rgba(255,255,255,0.4);
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  margin-top: 16px;
}

.btn-add, .btn-delete {
  padding: 12px 20px;
  border-radius: 8px;
  border: none;
  color: white;
  cursor: pointer;
  font-size: 0.95rem;
  transition: all 0.2s ease;
  font-weight: 600;
}

.btn-add {
  background-color: #2ecc71;
}

.btn-delete {
  background-color: #e74c3c;
}

.btn-add:hover, .btn-delete:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0,0,0,0.2);
}

.btn-add:active, .btn-delete:active {
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
  color: #74e0df;
  margin-bottom: 16px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  padding-bottom: 8px;
  font-weight: 600;
}

.users-container {
  padding: 16px 0;
}

.users-info {
  font-size: 1rem;
  color: #ccc;
  margin-bottom: 20px;
  text-align: left;
  display: flex;
  align-items: center;
  gap: 12px;
}

.info-badge {
  background-color: rgba(116,224,223,0.15);
  color: #74e0df;
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
  color: #74e0df;
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
  background-color: rgba(116,224,223,0.15);
  color: #74e0df;
  border-radius: 50%;
  margin-right: 10px;
}

.role-badge {
  display: inline-block;
  padding: 6px 12px;
  border-radius: 20px;
  font-size: 0.8rem;
  font-weight: 600;
  background-color: rgba(116,224,223,0.15);
  color: #74e0df;
}

.role-doctor {
  background-color: rgba(52, 152, 219, 0.2);
  color: #3498db;
}

.role-patient {
  background-color: rgba(46, 204, 113, 0.2);
  color: #2ecc71;
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
  color: #74e0df;
  opacity: 0.4;
  margin-bottom: 24px;
}

@media (min-width: 768px) {
  .form-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 768px) {
  .org-tabs {
    flex-wrap: nowrap;
    overflow-x: auto;
    padding-bottom: 5px;
  }
  
  .org-tabs__item {
    padding: 10px 12px;
    font-size: 0.9rem;
  }
  
  .users-info {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }
  
  .table th, .table td {
    padding: 10px 8px;
    font-size: 0.9rem;
  }
}
</style>
