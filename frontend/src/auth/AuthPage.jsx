export function AuthPage({ title, subtitle, children, className = "" }) {
  return (
    <main className="auth-page">
      <section className={`auth-card auth-page-card ${className}`.trim()}>
        <header className="auth-header">
          <div className="auth-copy">
            <h1>{title}</h1>
            <p className="auth-subtitle">{subtitle}</p>
          </div>
        </header>
        {children}
      </section>
    </main>
  );
}
