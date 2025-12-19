import { type ReactNode } from "react";
import { AuthProvider } from "@/ui/components/AuthProvider";

export const metadata = {
	title: process.env.NEXT_PUBLIC_SITE_NAME || "emerge",
	description: "E-commerce demo powered by Saleor & Next.js",
};

export default function RootLayout(props: { children: ReactNode }) {
	return (
		<main>
			<AuthProvider>{props.children}</AuthProvider>
		</main>
	);
}
