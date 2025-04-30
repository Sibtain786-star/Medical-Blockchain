<template>
  <div>
    <button class="btn btn-info btn-sm login-button" v-if="!isUserLoggedIn" v-on:click.prevent="login()">
      <Octicon :icon="reply" v-if="isLogin"></Octicon>
      <Octicon :icon="person" v-else-if="!isLogin"></Octicon>
    </button>
    <button class="btn btn-info btn-sm logout-button" v-else-if="isUserLoggedIn" v-on:click="logout()">
      <Octicon :icon="signOut"></Octicon>
    </button>

    <div class="form-group component-inner-container" v-if="isLogin">
      <textarea class="form-control" v-model="token" placeholder="Paste token here..."></textarea>
      <div class="button-container">
        <button type="submit" class="btn btn-info btn-sm jwt-submit" v-on:click="verifyLogin()">Login</button>
        <button type="button" class="btn btn-secondary btn-sm jwt-cancel" v-on:click="cancelLogin()">Cancel</button>
      </div>
      <div class="dummy-login-container">
        <h5>Use dummy login</h5>
        <button class="dummy-btn" @click="useDummyLogin()">Quick Login</button>
      </div>
    </div>
  </div>
</template>                                                     
                                                               
<script>                                                      
import Octicon, { person, reply, signOut } from 'octicons-vue'
import VueJwtDecode from 'vue-jwt-decode'
import config from '@/secrets/config.json'
import { serverBus } from '@/main'

export default {                                             
  name: 'Login',                                             
  props: {
    caller: String
  },
  components: {
    Octicon
  },
  data: () => ({
    person, reply, signOut,
    isLogin: false,
    isUserLoggedIn: false,
    token: ''
  }),
  created() {
    // Check if already logged in
    if (sessionStorage[`${this.caller}-token`] && sessionStorage[`${this.caller}-token`] !== '') {
      this.isUserLoggedIn = true;
    }
  },
  methods: {
    login () {
      this.isLogin = !this.isLogin
      if (this.isLogin) {
        // Instead of opening a new window, just show the login form
        // window.open(config.iss + '/onboarding/v1/logins', 'loginwindow', 'height=435,width=962')
      }
      serverBus.$emit(`${this.caller}-isLogin`, this.isLogin)
    },

    cancelLogin() {
      this.isLogin = false;
      this.token = '';
      serverBus.$emit(`${this.caller}-isLogin`, false);
    },

    logout () {
      sessionStorage[`${this.caller}-token`] = ""
      console.log("logout success")
      this.isUserLoggedIn = false
      serverBus.$emit(`${this.caller}-isLoggedIn`, false)
      serverBus.$emit(`${this.caller}-jwt`, {})
    },

    verifyLogin () {
      if (!this.token) {
        this.token = ''
        return this.loginFail()
      }

      return this.loginSuccess()
    },

    useDummyLogin() {
      // Create dummy JWT token
      const mockToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkR1bW15IFVzZXIiLCJpYXQiOjE1MTYyMzkwMjIsInVpZCI6InVzZXItMTIzIiwib2lkIjoib3JnLTEyMyIsInNpZCI6InNvbC0xMjMifQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c";
      this.token = mockToken;
      this.loginSuccess();
    },

    loginSuccess () {
      sessionStorage[`${this.caller}-token`] = this.token
      console.log("login success")
      this.isUserLoggedIn = true
      this.isLogin = !this.isLogin
      serverBus.$emit(`${this.caller}-isLogin`, this.isLogin)
      serverBus.$emit(`${this.caller}-isLoggedIn`, true)
      serverBus.$emit(`${this.caller}-jwt`, VueJwtDecode.decode(this.token))
      this.token = ''
    },

    loginFail () {
      console.log("login fail")
    }
  }
}                                                                         
</script>                                                                  
                                                                            
<!-- Add "scoped" attribute to limit CSS to this component only -->          
<style scoped>                           

.login-button {
  position: relative;
  top: -40px;
  left: calc(50vw/2 - 30px);
  padding: 8px 15px;
}

.logout-button {
  position: relative;
  top: -40px;
  left: calc(-50vw/2 + 30px);
  padding: 8px 15px;
}

.component-inner-container {
  padding: 20px;
  background-color: #1e1e2e;
  border-radius: 10px;
  box-shadow: 0 4px 8px rgba(0,0,0,0.2);
}

.button-container {
  display: flex;
  justify-content: center;
  gap: 10px;
  margin-top: 15px;
}

.jwt-submit, .jwt-cancel {
  padding: 8px 20px;
  border-radius: 5px;
  font-weight: 500;
  min-width: 100px;
  text-align: center;
}

.jwt-cancel {
  background-color: #6c757d;
}

textarea {
  height: calc(50vh - 200px) !important;
  background-color: rgb(73, 73, 73) !important;
  color: white !important;
  padding: 12px !important;
  resize: none;
  font-family: monospace;
}

.dummy-login-container {
  text-align: center;
  margin-top: 20px;
  padding-top: 15px;
  border-top: 1px solid rgba(255,255,255,0.1);
}

.dummy-login-container h5 {
  color: #aaa;
  font-size: 0.9rem;
  margin-bottom: 10px;
}

.dummy-btn {
  padding: 8px 15px;
  border-radius: 5px;
  border: none;
  background-color: #74e0df;
  color: #1e1e2e;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.dummy-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 2px 5px rgba(0,0,0,0.2);
}

</style>
