import { signOut } from "@/lib/auth/actions";
import { Button } from "@/components/ui/button";

export function SignOutButton() {
  return <form action={signOut}><Button type="submit" variant="ghost" size="sm" className="w-full justify-start text-muted-foreground">Terminar sessão</Button></form>;
}
