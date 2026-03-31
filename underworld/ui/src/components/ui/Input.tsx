// ============================================================
// UNDERWORLD — Input Component
// ============================================================

import type { InputHTMLAttributes } from 'react'

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string
  error?: string
}

export function Input({ label, error, className = '', ...props }: InputProps) {
  return (
    <div className="flex flex-col gap-1.5">
      {label && (
        <label className="text-xs font-medium text-zinc-400 uppercase tracking-wider">
          {label}
        </label>
      )}
      <input
        {...props}
        className={`
          w-full bg-surface-3 border border-white/8 rounded-lg px-3 py-2 text-sm text-white
          placeholder-zinc-600 outline-none
          focus:border-accent/60 focus:ring-1 focus:ring-accent/30
          transition-all duration-150
          ${error ? 'border-red-500/60' : ''}
          ${className}
        `}
      />
      {error && <span className="text-xs text-red-400">{error}</span>}
    </div>
  )
}

export function Select({
  label,
  error,
  className = '',
  children,
  ...props
}: React.SelectHTMLAttributes<HTMLSelectElement> & { label?: string; error?: string }) {
  return (
    <div className="flex flex-col gap-1.5">
      {label && (
        <label className="text-xs font-medium text-zinc-400 uppercase tracking-wider">
          {label}
        </label>
      )}
      <select
        {...props}
        className={`
          w-full bg-surface-3 border border-white/8 rounded-lg px-3 py-2 text-sm text-white
          outline-none focus:border-accent/60 focus:ring-1 focus:ring-accent/30
          transition-all duration-150 cursor-pointer
          ${error ? 'border-red-500/60' : ''}
          ${className}
        `}
      >
        {children}
      </select>
      {error && <span className="text-xs text-red-400">{error}</span>}
    </div>
  )
}
