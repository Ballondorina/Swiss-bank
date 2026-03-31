// ============================================================
// UNDERWORLD — Button Component
// ============================================================

import type { ButtonHTMLAttributes } from 'react'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'ghost' | 'danger' | 'success' | 'outline'
  size?: 'sm' | 'md' | 'lg'
}

const VARIANT_STYLES = {
  primary: 'bg-accent hover:bg-accent-dim text-white shadow-[0_0_12px_rgba(124,106,247,0.3)] hover:shadow-[0_0_18px_rgba(124,106,247,0.5)]',
  ghost:   'bg-surface-3 hover:bg-surface-4 text-zinc-300 hover:text-white',
  danger:  'bg-red-500/20 hover:bg-red-500/30 text-red-400 hover:text-red-300 border border-red-500/30',
  success: 'bg-green-500/20 hover:bg-green-500/30 text-green-400 hover:text-green-300 border border-green-500/30',
  outline: 'border border-zinc-600/60 hover:border-zinc-500 bg-transparent text-zinc-300 hover:text-white',
}

const SIZE_STYLES = {
  sm: 'px-3 py-1.5 text-xs',
  md: 'px-4 py-2 text-sm',
  lg: 'px-6 py-2.5 text-sm',
}

export function Button({
  variant = 'ghost',
  size = 'md',
  className = '',
  children,
  disabled,
  ...props
}: ButtonProps) {
  return (
    <button
      {...props}
      disabled={disabled}
      className={`
        inline-flex items-center gap-1.5 rounded-lg font-medium
        transition-all duration-150 cursor-pointer
        disabled:opacity-40 disabled:cursor-not-allowed
        ${VARIANT_STYLES[variant]}
        ${SIZE_STYLES[size]}
        ${className}
      `}
    >
      {children}
    </button>
  )
}
