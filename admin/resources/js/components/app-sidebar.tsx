import { Link } from '@inertiajs/react';
import {
    ClipboardList,
    FolderTree,
    GraduationCap,
    HeartHandshake,
    LayoutDashboard,
    Megaphone,
    MessageSquareText,
    PackageSearch,
    ReceiptText,
    ScrollText,
    ShieldCheck,
    Star,
    Store,
    Users,
} from 'lucide-react';
import AppLogo from '@/components/app-logo';
import { NavFooter } from '@/components/nav-footer';
import { NavMain } from '@/components/nav-main';
import { NavUser } from '@/components/nav-user';
import {
    Sidebar,
    SidebarContent,
    SidebarFooter,
    SidebarHeader,
    SidebarMenu,
    SidebarMenuButton,
    SidebarMenuItem,
} from '@/components/ui/sidebar';
import type { NavGroup, NavItem } from '@/types';

const navGroups: NavGroup[] = [
    {
        title: 'Utama',
        items: [
            {
                title: 'Dashboard',
                href: '/dashboard',
                icon: LayoutDashboard,
            },
            {
                title: 'Laporan Summary',
                href: '/reports',
                icon: ScrollText,
            },
        ],
    },
    {
        title: 'Kelola Toko & Produk',
        items: [
            {
                title: 'Kategori Produk',
                href: '/categories',
                icon: FolderTree,
            },
            {
                title: 'Toko UMK',
                href: '/stores',
                icon: Store,
            },
            {
                title: 'Produk UMK',
                href: '/products',
                icon: PackageSearch,
            },
            {
                title: 'Transaksi & Orders',
                href: '/orders',
                icon: ReceiptText,
            },
            {
                title: 'Konten & Promosi UMK',
                href: '/store-contents',
                icon: Megaphone,
            },
            {
                title: 'Rekomendasi Produk',
                href: '/recommendations',
                icon: Star,
            },
        ],
    },
    {
        title: 'Bantuan & Dispute',
        items: [
            {
                title: 'Refund & Cases',
                href: '/refund-cases',
                icon: ClipboardList,
            },
            {
                title: 'Pelatihan UMK',
                href: '/trainings',
                icon: GraduationCap,
            },
            {
                title: 'Donasi UMK',
                href: '/donations',
                icon: HeartHandshake,
            },
            {
                title: 'Kritik & Masukan',
                href: '/system-feedbacks',
                icon: MessageSquareText,
            },
        ],
    },
    {
        title: 'Pengguna & Log',
        items: [
            {
                title: 'Manajemen User',
                href: '/users',
                icon: Users,
            },
            {
                title: 'Roles & Permissions',
                href: '/roles',
                icon: ShieldCheck,
            },
            {
                title: 'Audit Logs',
                href: '/audit-logs',
                icon: ScrollText,
            },
        ],
    },
];

const footerNavItems: NavItem[] = [];

export function AppSidebar() {
    return (
        <Sidebar collapsible="icon" variant="inset">
            <SidebarHeader>
                <SidebarMenu>
                    <SidebarMenuItem>
                        <SidebarMenuButton size="lg" asChild>
                            <Link href="/dashboard" prefetch>
                                <AppLogo />
                            </Link>
                        </SidebarMenuButton>
                    </SidebarMenuItem>
                </SidebarMenu>
            </SidebarHeader>

            <SidebarContent>
                <NavMain groups={navGroups} />
            </SidebarContent>

            <SidebarFooter>
                <NavFooter items={footerNavItems} className="mt-auto" />
                <NavUser />
            </SidebarFooter>
        </Sidebar>
    );
}
