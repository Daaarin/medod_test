import { useState } from "react";

export function PasswordField({ label = "Пароль", value, onChange, autoComplete = "current-password" }) {
  const [visible, setVisible] = useState(false);

  return (
    <label className="auth-field auth-field-password">
      <span>{label}</span>
      <div className="auth-password-row">
        <input
          autoComplete={autoComplete}
          type={visible ? "text" : "password"}
          value={value}
          onChange={onChange}
          required
        />
        <button
          type="button"
          className="auth-password-toggle"
          aria-label={visible ? "Скрыть пароль" : "Показать пароль"}
          aria-pressed={visible}
          onClick={() => setVisible((current) => !current)}
        >
          <svg aria-hidden="true" viewBox="0 0 24 24">
            <path
              d="M2.5 12s3.6-7.5 9.5-7.5S21.5 12 21.5 12 17.9 19.5 12 19.5 2.5 12 2.5 12Z"
              fill="none"
              stroke="currentColor"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth="1.8"
            />
            <circle cx="12" cy="12" r="3.1" fill="none" stroke="currentColor" strokeWidth="1.8" />
            {visible ? <path d="M4.5 19.5 19.5 4.5" fill="none" stroke="currentColor" strokeWidth="1.8" /> : null}
          </svg>
          <span>{visible ? "скрыть" : "показать"}</span>
        </button>
      </div>
    </label>
  );
}
