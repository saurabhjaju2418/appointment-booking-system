import type { Metadata, ReactNode } from "react";
import "./globals.css";
export const metadata: Metadata = { title: "Slotwise — Booking Studio", description: "Simple, thoughtful appointment scheduling." };
export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) { return <html lang="en"><body>{children}</body></html>; }

