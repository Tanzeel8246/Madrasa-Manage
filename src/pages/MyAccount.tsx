import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { useAuth } from "@/contexts/AuthContext";
import { supabase } from "@/integrations/supabase/untypedClient";
import { toast } from "sonner";
import { Loader2, Upload, User, Building2 } from "lucide-react";
import { useTranslation } from "react-i18next";

export default function MyAccount() {
  const { user, madrasaName } = useAuth();
  const { t } = useTranslation();
  const [isLoading, setIsLoading] = useState(false);
  const [isUploadingLogo, setIsUploadingLogo] = useState(false);
  const [fullName, setFullName] = useState("");
  const [newMadrasaName, setNewMadrasaName] = useState("");
  const [logoUrl, setLogoUrl] = useState("");

  // Load current profile data
  useState(() => {
    if (user) {
      supabase
        .from('profiles')
        .select('full_name, madrasa_name, logo_url')
        .eq('id', user.id)
        .single()
        .then(({ data }) => {
          if (data) {
            setFullName(data.full_name || '');
            setNewMadrasaName(data.madrasa_name || '');
            setLogoUrl(data.logo_url || '');
          }
        });
    }
  });

  const handleLogoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || e.target.files.length === 0 || !user) return;

    const file = e.target.files[0];
    const fileExt = file.name.split('.').pop();
    const filePath = `${user.id}/${Date.now()}.${fileExt}`;

    try {
      setIsUploadingLogo(true);

      // Upload to storage
      const { error: uploadError } = await supabase.storage
        .from('madrasa-logos')
        .upload(filePath, file);

      if (uploadError) throw uploadError;

      // Get public URL
      const { data: { publicUrl } } = supabase.storage
        .from('madrasa-logos')
        .getPublicUrl(filePath);

      // Update profile
      const { error: updateError } = await supabase
        .from('profiles')
        .update({ logo_url: publicUrl })
        .eq('id', user.id);

      if (updateError) throw updateError;

      setLogoUrl(publicUrl);
      toast.success(t('logoUpdated') || 'Logo updated successfully!');
    } catch (error: any) {
      toast.error(error.message || 'Failed to upload logo');
    } finally {
      setIsUploadingLogo(false);
    }
  };

  const handleUpdateProfile = async () => {
    if (!user) return;

    try {
      setIsLoading(true);

      const { error } = await supabase
        .from('profiles')
        .update({
          full_name: fullName,
          madrasa_name: newMadrasaName,
        })
        .eq('id', user.id);

      if (error) throw error;

      toast.success(t('profileUpdated') || 'Profile updated successfully!');
    } catch (error: any) {
      toast.error(error.message || 'Failed to update profile');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="space-y-6 max-w-4xl">
      <div>
        <h1 className="text-2xl md:text-3xl font-bold text-foreground">{t('myAccount') || 'My Account'}</h1>
        <p className="text-muted-foreground mt-1 text-sm md:text-base">
          {t('manageAccountSettings') || 'Manage your account settings and madrasa information'}
        </p>
      </div>

      <div className="grid gap-6">
        {/* Profile Information */}
        <Card className="shadow-elevated">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <User className="h-5 w-5" />
              {t('profileInformation') || 'Profile Information'}
            </CardTitle>
            <CardDescription>
              {t('updateProfileDetails') || 'Update your personal information'}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email">{t('email') || 'Email'}</Label>
              <Input
                id="email"
                type="email"
                value={user?.email || ''}
                disabled
                className="bg-muted"
              />
              <p className="text-xs text-muted-foreground">
                {t('emailCannotBeChanged') || 'Email cannot be changed'}
              </p>
            </div>

            <div className="space-y-2">
              <Label htmlFor="fullName">{t('fullName') || 'Full Name'}</Label>
              <Input
                id="fullName"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                placeholder={t('enterFullName') || 'Enter your full name'}
              />
            </div>

            <Button onClick={handleUpdateProfile} disabled={isLoading}>
              {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {t('saveChanges') || 'Save Changes'}
            </Button>
          </CardContent>
        </Card>

        {/* Madrasa Information */}
        <Card className="shadow-elevated">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Building2 className="h-5 w-5" />
              {t('madrasaInformation') || 'Madrasa Information'}
            </CardTitle>
            <CardDescription>
              {t('manageMadrasaDetails') || 'Manage your madrasa details and branding'}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="space-y-2">
              <Label htmlFor="madrasaName">{t('madrasaName') || 'Madrasa Name'}</Label>
              <Input
                id="madrasaName"
                value={newMadrasaName}
                onChange={(e) => setNewMadrasaName(e.target.value)}
                placeholder={t('enterMadrasaName') || 'Enter madrasa name'}
              />
            </div>

            <div className="space-y-4">
              <Label>{t('madrasaLogo') || 'Madrasa Logo'}</Label>
              <div className="flex items-center gap-4">
                <Avatar className="h-20 w-20">
                  <AvatarImage src={logoUrl} alt="Madrasa Logo" />
                  <AvatarFallback className="bg-primary text-primary-foreground text-2xl">
                    {newMadrasaName?.charAt(0) || 'M'}
                  </AvatarFallback>
                </Avatar>
                <div className="flex-1">
                  <Input
                    type="file"
                    accept="image/*"
                    onChange={handleLogoUpload}
                    disabled={isUploadingLogo}
                    className="hidden"
                    id="logo-upload"
                  />
                  <Label htmlFor="logo-upload" className="cursor-pointer">
                    <Button
                      type="button"
                      variant="outline"
                      disabled={isUploadingLogo}
                      asChild
                    >
                      <span>
                        {isUploadingLogo ? (
                          <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        ) : (
                          <Upload className="mr-2 h-4 w-4" />
                        )}
                        {t('uploadLogo') || 'Upload Logo'}
                      </span>
                    </Button>
                  </Label>
                  <p className="text-xs text-muted-foreground mt-2">
                    {t('logoRequirements') || 'PNG, JPG up to 5MB. Recommended 200x200px'}
                  </p>
                </div>
              </div>
            </div>

            <Button onClick={handleUpdateProfile} disabled={isLoading}>
              {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {t('saveChanges') || 'Save Changes'}
            </Button>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
