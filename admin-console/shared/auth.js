// Shared authentication logic for all admin consoles

class AdminAuth {
    constructor() {
        this.currentUser = null;
        this.isAdmin = false;
        this.init();
    }

    async init() {
        // Wait for Firebase to initialize
        await new Promise((resolve) => {
            if (firebase.apps.length > 0) {
                resolve();
            } else {
                setTimeout(resolve, 100);
            }
        });

        // Listen for auth state changes
        firebase.auth().onAuthStateChanged(async (user) => {
            if (user) {
                await this.handleUserSignedIn(user);
            } else {
                this.handleUserSignedOut();
            }
        });

        // Set up UI event listeners
        this.setupEventListeners();
    }

    async handleUserSignedIn(user) {
        this.currentUser = user;
        
        try {
            // Check if user has admin privileges
            const idTokenResult = await user.getIdTokenResult();
            this.isAdmin = !!idTokenResult.claims.admin;
            
            if (this.isAdmin) {
                this.showAdminInterface();
                this.updateUserInfo();
            } else {
                this.showError('Access denied. Admin privileges required.');
                await this.signOut();
            }
        } catch (error) {
            console.error('Error checking admin claims:', error);
            this.showError('Authentication error. Please try again.');
            await this.signOut();
        }
    }

    handleUserSignedOut() {
        this.currentUser = null;
        this.isAdmin = false;
        this.showAuthInterface();
        this.clearUserInfo();
    }

    showAuthInterface() {
        const authSection = document.getElementById('authSection');
        const adminContent = document.getElementById('adminDashboard') || document.getElementById('adminHub');
        
        if (authSection) authSection.classList.remove('hidden');
        if (adminContent) adminContent.classList.add('hidden');
    }

    showAdminInterface() {
        const authSection = document.getElementById('authSection');
        const adminContent = document.getElementById('adminDashboard') || document.getElementById('adminHub');
        
        if (authSection) authSection.classList.add('hidden');
        if (adminContent) adminContent.classList.remove('hidden');
    }

    updateUserInfo() {
        const userEmailElement = document.getElementById('userEmail');
        if (userEmailElement && this.currentUser) {
            userEmailElement.textContent = this.currentUser.email;
        }
    }

    clearUserInfo() {
        const userEmailElement = document.getElementById('userEmail');
        if (userEmailElement) {
            userEmailElement.textContent = '';
        }
    }

    setupEventListeners() {
        // Login form
        const loginForm = document.getElementById('loginForm');
        if (loginForm) {
            loginForm.addEventListener('submit', async (e) => {
                e.preventDefault();
                await this.handleLogin();
            });
        }

        // Sign out button
        const signOutBtn = document.getElementById('signOutBtn');
        if (signOutBtn) {
            signOutBtn.addEventListener('click', async () => {
                await this.signOut();
            });
        }
    }

    async handleLogin() {
        const email = document.getElementById('email').value;
        const password = document.getElementById('password').value;
        
        try {
            this.clearError();
            await firebase.auth().signInWithEmailAndPassword(email, password);
        } catch (error) {
            console.error('Login error:', error);
            this.showError(this.getErrorMessage(error.code));
        }
    }

    async signOut() {
        try {
            await firebase.auth().signOut();
        } catch (error) {
            console.error('Sign out error:', error);
        }
    }

    showError(message) {
        const errorElement = document.getElementById('authError');
        if (errorElement) {
            errorElement.textContent = message;
            errorElement.classList.remove('hidden');
        }
    }

    clearError() {
        const errorElement = document.getElementById('authError');
        if (errorElement) {
            errorElement.textContent = '';
            errorElement.classList.add('hidden');
        }
    }

    getErrorMessage(errorCode) {
        const errorMessages = {
            'auth/user-not-found': 'No account found with this email address.',
            'auth/wrong-password': 'Incorrect password.',
            'auth/invalid-email': 'Invalid email address format.',
            'auth/user-disabled': 'This account has been disabled.',
            'auth/too-many-requests': 'Too many failed attempts. Please try again later.',
            'auth/network-request-failed': 'Network error. Please check your connection.'
        };
        
        return errorMessages[errorCode] || 'An error occurred. Please try again.';
    }

    // Utility method to check if user is authenticated and has admin privileges
    requireAdmin() {
        if (!this.currentUser || !this.isAdmin) {
            throw new Error('Admin authentication required');
        }
        return true;
    }

    // Get authenticated user
    getUser() {
        return this.currentUser;
    }

    // Check if user has admin privileges
    hasAdminAccess() {
        return this.isAdmin;
    }
}

// Initialize admin auth when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.adminAuth = new AdminAuth();
});

// Export for use in other scripts
window.AdminAuth = AdminAuth;