// Shared navigation component for admin consoles

class AdminNavigation {
    constructor() {
        this.currentFeature = this.detectCurrentFeature();
    }

    detectCurrentFeature() {
        const path = window.location.pathname;
        if (path.includes('/home-services/')) return 'home-services';
        if (path.includes('/ride-sharing/')) return 'ride-sharing';
        if (path.includes('/debate/')) return 'debate';
        if (path.includes('/image-lessons/')) return 'image-lessons';
        return 'hub';
    }

    // Add breadcrumb navigation
    addBreadcrumb(container) {
        const breadcrumb = document.createElement('nav');
        breadcrumb.className = 'flex items-center space-x-2 text-sm text-gray-600 mb-6';
        
        const homeLink = document.createElement('a');
        homeLink.href = '../';
        homeLink.className = 'hover:text-indigo-600';
        homeLink.innerHTML = '<i class="fas fa-home mr-1"></i>Admin Hub';
        
        const separator = document.createElement('span');
        separator.textContent = '/';
        separator.className = 'text-gray-400';
        
        const currentPage = document.createElement('span');
        currentPage.textContent = this.getFeatureName(this.currentFeature);
        currentPage.className = 'text-gray-900 font-medium';
        
        breadcrumb.appendChild(homeLink);
        breadcrumb.appendChild(separator);
        breadcrumb.appendChild(currentPage);
        
        container.insertBefore(breadcrumb, container.firstChild);
    }

    getFeatureName(feature) {
        const names = {
            'home-services': 'Home Services',
            'ride-sharing': 'Ride Sharing',
            'debate': 'Debate Platform',
            'image-lessons': 'Image Lessons',
            'hub': 'Admin Hub'
        };
        return names[feature] || 'Unknown';
    }

    // Add back to hub button
    addBackButton(container) {
        if (this.currentFeature === 'hub') return;
        
        const backButton = document.createElement('a');
        backButton.href = '../';
        backButton.className = 'inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 mb-4';
        backButton.innerHTML = '<i class="fas fa-arrow-left mr-2"></i>Back to Admin Hub';
        
        container.insertBefore(backButton, container.firstChild);
    }
}

// Auto-initialize navigation components
document.addEventListener('DOMContentLoaded', () => {
    const nav = new AdminNavigation();
    
    // Add breadcrumb to main content areas
    const mainContent = document.querySelector('.max-w-7xl.mx-auto');
    if (mainContent && nav.currentFeature !== 'hub') {
        nav.addBreadcrumb(mainContent);
    }
});

window.AdminNavigation = AdminNavigation;