'use client'

import React, { createContext, useCallback, useContext, useEffect, useState } from 'react'
import { FALLBACK_RELEASE, type LatestReleaseInfo } from '@/lib/releases'

export type Locale = 'en' | 'pt'
export type ThemeMode = 'light' | 'dark'

interface AppContextValue {
  locale: Locale
  setLocale: (locale: Locale) => void
  theme: ThemeMode
  toggleTheme: () => void
  isPaletteOpen: boolean
  openPalette: () => void
  closePalette: () => void
  /** Latest GitHub Release, fetched server-side in the root layout. */
  release: LatestReleaseInfo
}

const AppContext = createContext<AppContextValue>({
  locale: 'en',
  setLocale: () => {},
  theme: 'light',
  toggleTheme: () => {},
  isPaletteOpen: false,
  openPalette: () => {},
  closePalette: () => {},
  release: FALLBACK_RELEASE,
})

export function AppProviders({
  children,
  release = FALLBACK_RELEASE,
}: {
  children: React.ReactNode
  release?: LatestReleaseInfo
}) {
  const [locale, setLocaleState] = useState<Locale>('en')
  const [theme, setTheme] = useState<ThemeMode>('light')
  const [isPaletteOpen, setIsPaletteOpen] = useState(false)

  useEffect(() => {
    const savedLocale = localStorage.getItem('mbl-locale') as Locale | null
    if (savedLocale === 'en' || savedLocale === 'pt') {
      setLocaleState(savedLocale)
    }
    const savedTheme = localStorage.getItem('mbl-theme') as ThemeMode | null
    if (savedTheme === 'light' || savedTheme === 'dark') {
      setTheme(savedTheme)
      document.documentElement.classList.toggle('dark', savedTheme === 'dark')
    }
  }, [])

  // Global ⌘K / Ctrl+K Spotlight Command Palette shortcut (matching macOS app)
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        setIsPaletteOpen((prev) => !prev)
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [])

  const setLocale = useCallback((next: Locale) => {
    setLocaleState(next)
    localStorage.setItem('mbl-locale', next)
  }, [])

  const toggleTheme = useCallback(() => {
    setTheme((prev) => {
      const next: ThemeMode = prev === 'light' ? 'dark' : 'light'
      localStorage.setItem('mbl-theme', next)
      document.documentElement.classList.toggle('dark', next === 'dark')
      return next
    })
  }, [])

  const openPalette = useCallback(() => setIsPaletteOpen(true), [])
  const closePalette = useCallback(() => setIsPaletteOpen(false), [])

  return (
    <AppContext.Provider
      value={{
        locale,
        setLocale,
        theme,
        toggleTheme,
        isPaletteOpen,
        openPalette,
        closePalette,
        release,
      }}
    >
      {children}
    </AppContext.Provider>
  )
}

export function useAppContext() {
  return useContext(AppContext)
}
