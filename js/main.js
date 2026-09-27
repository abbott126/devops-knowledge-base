// Theme toggle
const themeToggle = document.getElementById('themeToggle');
const html = document.documentElement;

const saved = localStorage.getItem('theme');
if (saved) {
  html.setAttribute('data-theme', saved);
  themeToggle.textContent = saved === 'dark' ? '☀️' : '🌙';
}

themeToggle.addEventListener('click', () => {
  const current = html.getAttribute('data-theme');
  const next = current === 'dark' ? 'light' : 'dark';
  html.setAttribute('data-theme', next);
  localStorage.setItem('theme', next);
  themeToggle.textContent = next === 'dark' ? '☀️' : '🌙';
});

// Mobile menu
const menuToggle = document.querySelector('.menu-toggle');
const navLinks = document.querySelector('.nav-links');
if (menuToggle) {
  menuToggle.addEventListener('click', () => {
    navLinks.classList.toggle('active');
  });
}

// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function(e) {
    const target = document.querySelector(this.getAttribute('href'));
    if (target) {
      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth' });
    }
  });
});

// Active TOC tracking
const tocLinks = document.querySelectorAll('.toc a');
const headings = document.querySelectorAll('.doc-content h1, .doc-content h2, .doc-content h3');

function updateActiveToc() {
  let current = '';
  headings.forEach(h => {
    const rect = h.getBoundingClientRect();
    if (rect.top <= 100) current = h.id;
  });
  tocLinks.forEach(link => {
    link.classList.toggle('active', link.getAttribute('href') === '#' + current);
  });
}

window.addEventListener('scroll', updateActiveToc, { passive: true });
updateActiveToc();

// Search functionality (simple)
const searchInput = document.querySelector('.hero-search input');
if (searchInput) {
  searchInput.addEventListener('input', function() {
    const query = this.value.toLowerCase();
    document.querySelectorAll('.topic-card').forEach(card => {
      const text = card.textContent.toLowerCase();
      card.style.display = query === '' || text.includes(query) ? '' : 'none';
    });
    document.querySelectorAll('.doc-list li').forEach(li => {
      const text = li.textContent.toLowerCase();
      li.style.display = query === '' || text.includes(query) ? '' : 'none';
    });
    document.querySelectorAll('.doc-list a').forEach(a => {
      const li = a.closest('li');
      if (li) li.style.display = query === '' || a.textContent.toLowerCase().includes(query) ? '' : 'none';
    });
  });
}
