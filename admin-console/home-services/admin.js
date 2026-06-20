// Firebase is initialized in firebase-config.js

const auth = firebase.auth();
const db = firebase.firestore();
const functions = firebase.functions();

// DOM elements
const authSection = document.getElementById('authSection');
const adminDashboard = document.getElementById('adminDashboard');
const loginForm = document.getElementById('loginForm');
const authError = document.getElementById('authError');
const userEmail = document.getElementById('userEmail');
const signOutBtn = document.getElementById('signOutBtn');

// Tab elements
const tabBtns = document.querySelectorAll('.tab-btn');
const tabContents = document.querySelectorAll('.tab-content');

// Modal elements
const categoryModal = document.getElementById('categoryModal');
const addCategoryBtn = document.getElementById('addCategoryBtn');
const cancelCategoryBtn = document.getElementById('cancelCategoryBtn');
const categoryForm = document.getElementById('categoryForm');

// Current user
let currentUser = null;

// Auth state listener
auth.onAuthStateChanged(async (user) => {
    if (user) {
        currentUser = user;
        
        // Check if user has admin privileges
        const idTokenResult = await user.getIdTokenResult();
        if (idTokenResult.claims.admin) {
            showAdminDashboard();
        } else {
            showError('You do not have admin privileges');
            auth.signOut();
        }
    } else {
        showAuthSection();
    }
});

// Show auth section
function showAuthSection() {
    authSection.classList.remove('hidden');
    adminDashboard.classList.add('hidden');
    clearError();
}

// Show admin dashboard
function showAdminDashboard() {
    authSection.classList.add('hidden');
    adminDashboard.classList.remove('hidden');
    userEmail.textContent = currentUser.email;
    loadDashboardStats();
    loadCategories();
}

// Show error message
function showError(message) {
    authError.textContent = message;
    authError.classList.remove('hidden');
}

// Clear error message
function clearError() {
    authError.textContent = '';
    authError.classList.add('hidden');
}

// Login form handler
loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    clearError();
    
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    
    try {
        await auth.signInWithEmailAndPassword(email, password);
    } catch (error) {
        showError(error.message);
    }
});

// Sign out handler
signOutBtn.addEventListener('click', () => {
    auth.signOut();
});

// Tab switching
tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        const targetTab = btn.dataset.tab;
        switchTab(targetTab);
    });
});

function switchTab(tabName) {
    // Update tab buttons
    tabBtns.forEach(btn => {
        if (btn.dataset.tab === tabName) {
            btn.classList.add('border-indigo-500', 'text-indigo-600');
            btn.classList.remove('border-transparent', 'text-gray-500');
        } else {
            btn.classList.remove('border-indigo-500', 'text-indigo-600');
            btn.classList.add('border-transparent', 'text-gray-500');
        }
    });
    
    // Update tab content
    tabContents.forEach(content => {
        content.classList.add('hidden');
    });
    document.getElementById(tabName + 'Tab').classList.remove('hidden');
    
    // Load tab-specific data
    switch (tabName) {
        case 'categories':
            loadCategories();
            break;
        case 'rfqs':
            loadRFQs();
            break;
        case 'disputes':
            loadDisputes();
            break;
        case 'professionals':
            loadProfessionals();
            break;
    }
}

// Load dashboard stats
async function loadDashboardStats() {
    try {
        const [activeRfqs, activeContracts, openDisputes, totalPros] = await Promise.all([
            db.collection('rfqs').where('status', '==', 'open').get(),
            db.collection('contracts').where('status', '==', 'active').get(),
            db.collection('disputes').where('status', '==', 'open').get(),
            db.collection('proProfiles').where('isActive', '==', true).get()
        ]);
        
        document.getElementById('activeRfqsCount').textContent = activeRfqs.size;
        document.getElementById('activeContractsCount').textContent = activeContracts.size;
        document.getElementById('openDisputesCount').textContent = openDisputes.size;
        document.getElementById('totalProsCount').textContent = totalPros.size;
    } catch (error) {
        console.error('Error loading dashboard stats:', error);
    }
}

// Load categories
async function loadCategories() {
    try {
        const snapshot = await db.collection('serviceCategories')
            .orderBy('displayOrder')
            .get();
        
        const categoriesList = document.getElementById('categoriesList');
        categoriesList.innerHTML = '';
        
        snapshot.docs.forEach(doc => {
            const category = { id: doc.id, ...doc.data() };
            const categoryElement = createCategoryElement(category);
            categoriesList.appendChild(categoryElement);
        });
    } catch (error) {
        console.error('Error loading categories:', error);
    }
}

// Create category element
function createCategoryElement(category) {
    const div = document.createElement('div');
    div.className = 'border rounded-lg p-4 flex items-center justify-between';
    
    div.innerHTML = `
        <div class="flex items-center space-x-4">
            <div class="w-12 h-12 bg-indigo-100 rounded-lg flex items-center justify-center">
                <i class="fas fa-${category.icon.replace('.fill', '')} text-indigo-600"></i>
            </div>
            <div>
                <h4 class="font-medium">${category.name}</h4>
                <p class="text-sm text-gray-600">
                    AR: ${category.nameAr || 'N/A'} | FR: ${category.nameFr || 'N/A'}
                </p>
                <span class="inline-block px-2 py-1 text-xs rounded ${category.isActive ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}">
                    ${category.isActive ? 'Active' : 'Inactive'}
                </span>
            </div>
        </div>
        <div class="flex space-x-2">
            <button onclick="editCategory('${category.id}')" class="text-blue-600 hover:text-blue-800">
                <i class="fas fa-edit"></i>
            </button>
            <button onclick="toggleCategory('${category.id}', ${!category.isActive})" 
                    class="text-${category.isActive ? 'red' : 'green'}-600 hover:text-${category.isActive ? 'red' : 'green'}-800">
                <i class="fas fa-${category.isActive ? 'pause' : 'play'}-circle"></i>
            </button>
        </div>
    `;
    
    return div;
}

// Load RFQs
async function loadRFQs() {
    try {
        const statusFilter = document.getElementById('rfqStatusFilter').value;
        let query = db.collection('rfqs').orderBy('createdAt', 'desc').limit(20);
        
        if (statusFilter) {
            query = query.where('status', '==', statusFilter);
        }
        
        const snapshot = await query.get();
        const rfqsList = document.getElementById('rfqsList');
        rfqsList.innerHTML = '';
        
        snapshot.docs.forEach(doc => {
            const rfq = { id: doc.id, ...doc.data() };
            const rfqElement = createRFQElement(rfq);
            rfqsList.appendChild(rfqElement);
        });
    } catch (error) {
        console.error('Error loading RFQs:', error);
    }
}

// Create RFQ element
function createRFQElement(rfq) {
    const div = document.createElement('div');
    div.className = 'border rounded-lg p-4';
    
    const createdAt = rfq.createdAt ? new Date(rfq.createdAt.toDate()).toLocaleDateString() : 'N/A';
    
    div.innerHTML = `
        <div class="flex justify-between items-start">
            <div>
                <h4 class="font-medium">${rfq.scope?.title || 'Untitled RFQ'}</h4>
                <p class="text-sm text-gray-600">${rfq.scope?.description || ''}</p>
                <div class="mt-2 flex space-x-4 text-xs text-gray-500">
                    <span><i class="fas fa-map-marker-alt mr-1"></i>${rfq.location?.city || 'N/A'}</span>
                    <span><i class="fas fa-calendar mr-1"></i>${createdAt}</span>
                    <span><i class="fas fa-eye mr-1"></i>${rfq.bidCount || 0} bids</span>
                </div>
            </div>
            <div class="flex items-center space-x-2">
                <span class="px-2 py-1 text-xs rounded ${getStatusColor(rfq.status)}">
                    ${rfq.status}
                </span>
                <div class="flex space-x-1">
                    <button onclick="viewRFQ('${rfq.id}')" class="text-blue-600 hover:text-blue-800">
                        <i class="fas fa-eye"></i>
                    </button>
                    <button onclick="moderateRFQ('${rfq.id}')" class="text-yellow-600 hover:text-yellow-800">
                        <i class="fas fa-flag"></i>
                    </button>
                </div>
            </div>
        </div>
    `;
    
    return div;
}

// Load disputes
async function loadDisputes() {
    try {
        const statusFilter = document.getElementById('disputeStatusFilter').value;
        let query = db.collection('disputes').orderBy('createdAt', 'desc').limit(20);
        
        if (statusFilter) {
            query = query.where('status', '==', statusFilter);
        }
        
        const snapshot = await query.get();
        const disputesList = document.getElementById('disputesList');
        disputesList.innerHTML = '';
        
        snapshot.docs.forEach(doc => {
            const dispute = { id: doc.id, ...doc.data() };
            const disputeElement = createDisputeElement(dispute);
            disputesList.appendChild(disputeElement);
        });
    } catch (error) {
        console.error('Error loading disputes:', error);
    }
}

// Create dispute element
function createDisputeElement(dispute) {
    const div = document.createElement('div');
    div.className = 'border rounded-lg p-4';
    
    const createdAt = dispute.createdAt ? new Date(dispute.createdAt.toDate()).toLocaleDateString() : 'N/A';
    
    div.innerHTML = `
        <div class="flex justify-between items-start">
            <div>
                <h4 class="font-medium">Dispute: ${dispute.reason}</h4>
                <p class="text-sm text-gray-600">${dispute.description}</p>
                <div class="mt-2 flex space-x-4 text-xs text-gray-500">
                    <span><i class="fas fa-user mr-1"></i>Reporter: ${dispute.reporterRole}</span>
                    <span><i class="fas fa-calendar mr-1"></i>${createdAt}</span>
                </div>
            </div>
            <div class="flex items-center space-x-2">
                <span class="px-2 py-1 text-xs rounded ${getStatusColor(dispute.status)}">
                    ${dispute.status}
                </span>
                <div class="flex space-x-1">
                    <button onclick="viewDispute('${dispute.id}')" class="text-blue-600 hover:text-blue-800">
                        <i class="fas fa-eye"></i>
                    </button>
                    <button onclick="resolveDispute('${dispute.id}')" class="text-green-600 hover:text-green-800">
                        <i class="fas fa-check"></i>
                    </button>
                </div>
            </div>
        </div>
    `;
    
    return div;
}

// Load professionals
async function loadProfessionals() {
    try {
        const verificationFilter = document.getElementById('verificationFilter').value;
        let query = db.collection('proProfiles').orderBy('createdAt', 'desc').limit(20);
        
        if (verificationFilter === 'pending') {
            query = query.where('verification.isVerified', '==', false);
        } else if (verificationFilter === 'verified') {
            query = query.where('verification.isVerified', '==', true);
        }
        
        const snapshot = await query.get();
        const professionalsList = document.getElementById('professionalsList');
        professionalsList.innerHTML = '';
        
        snapshot.docs.forEach(doc => {
            const pro = { id: doc.id, ...doc.data() };
            const proElement = createProfessionalElement(pro);
            professionalsList.appendChild(proElement);
        });
    } catch (error) {
        console.error('Error loading professionals:', error);
    }
}

// Create professional element
function createProfessionalElement(pro) {
    const div = document.createElement('div');
    div.className = 'border rounded-lg p-4';
    
    const isVerified = pro.verification?.isVerified;
    const rating = pro.rating?.average || 0;
    
    div.innerHTML = `
        <div class="flex justify-between items-start">
            <div>
                <h4 class="font-medium">${pro.businessName}</h4>
                <p class="text-sm text-gray-600">${pro.serviceCategories?.join(', ') || 'No categories'}</p>
                <div class="mt-2 flex space-x-4 text-xs text-gray-500">
                    <span><i class="fas fa-map-marker-alt mr-1"></i>${pro.serviceArea?.city || 'N/A'}</span>
                    <span><i class="fas fa-star mr-1"></i>${rating.toFixed(1)} (${pro.rating?.count || 0} reviews)</span>
                    <span><i class="fas fa-briefcase mr-1"></i>${pro.experience?.completedJobs || 0} jobs</span>
                </div>
            </div>
            <div class="flex items-center space-x-2">
                <span class="px-2 py-1 text-xs rounded ${isVerified ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'}">
                    ${isVerified ? 'Verified' : 'Pending'}
                </span>
                <div class="flex space-x-1">
                    <button onclick="viewProfessional('${pro.id}')" class="text-blue-600 hover:text-blue-800">
                        <i class="fas fa-eye"></i>
                    </button>
                    ${!isVerified ? `<button onclick="verifyProfessional('${pro.id}')" class="text-green-600 hover:text-green-800">
                        <i class="fas fa-check"></i>
                    </button>` : ''}
                </div>
            </div>
        </div>
    `;
    
    return div;
}

// Utility functions
function getStatusColor(status) {
    const colors = {
        open: 'bg-green-100 text-green-800',
        closed: 'bg-gray-100 text-gray-800',
        expired: 'bg-red-100 text-red-800',
        active: 'bg-blue-100 text-blue-800',
        completed: 'bg-green-100 text-green-800',
        cancelled: 'bg-red-100 text-red-800',
        pending: 'bg-yellow-100 text-yellow-800',
        resolved: 'bg-green-100 text-green-800'
    };
    return colors[status] || 'bg-gray-100 text-gray-800';
}

// Modal handlers
addCategoryBtn.addEventListener('click', () => {
    categoryModal.classList.remove('hidden');
    categoryModal.classList.add('flex');
});

cancelCategoryBtn.addEventListener('click', () => {
    categoryModal.classList.add('hidden');
    categoryModal.classList.remove('flex');
    categoryForm.reset();
});

categoryForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const categoryData = {
        name: document.getElementById('categoryName').value,
        nameAr: document.getElementById('categoryNameAr').value,
        nameFr: document.getElementById('categoryNameFr').value,
        icon: document.getElementById('categoryIcon').value,
        displayOrder: parseInt(document.getElementById('categoryOrder').value) || 0,
        isActive: true
    };
    
    try {
        const createCategory = functions.httpsCallable('createCategory');
        await createCategory(categoryData);
        
        categoryModal.classList.add('hidden');
        categoryModal.classList.remove('flex');
        categoryForm.reset();
        loadCategories();
    } catch (error) {
        console.error('Error creating category:', error);
        alert('Error creating category: ' + error.message);
    }
});

// Action handlers (to be implemented)
window.editCategory = (categoryId) => {
    console.log('Edit category:', categoryId);
    // Implement edit functionality
};

window.toggleCategory = async (categoryId, isActive) => {
    try {
        const updateCategory = functions.httpsCallable('updateCategory');
        await updateCategory({ categoryId, isActive });
        loadCategories();
    } catch (error) {
        console.error('Error toggling category:', error);
    }
};

window.viewRFQ = (rfqId) => {
    console.log('View RFQ:', rfqId);
    // Implement view functionality
};

window.moderateRFQ = (rfqId) => {
    console.log('Moderate RFQ:', rfqId);
    // Implement moderation functionality
};

window.viewDispute = (disputeId) => {
    console.log('View dispute:', disputeId);
    // Implement view functionality
};

window.resolveDispute = (disputeId) => {
    console.log('Resolve dispute:', disputeId);
    // Implement resolve functionality
};

window.viewProfessional = (proId) => {
    console.log('View professional:', proId);
    // Implement view functionality
};

window.verifyProfessional = async (proId) => {
    try {
        if (confirm('Verify this professional?')) {
            const verify = functions.httpsCallable('verifyProfessional');
            await verify({ proId });
            loadProfessionals();
        }
    } catch (error) {
        console.error('Error verifying professional:', error);
    }
};

// Filter change handlers
document.getElementById('rfqStatusFilter').addEventListener('change', loadRFQs);
document.getElementById('disputeStatusFilter').addEventListener('change', loadDisputes);
document.getElementById('verificationFilter').addEventListener('change', loadProfessionals);